// keybind-menu.cpp — rofi-based Hyprland keybind viewer/editor.
//
// Parses `bind*` lines out of ~/.config/hypr/keybinds-extra.conf and
// ~/.config/hypr/hyprland.conf (in that order), lists them in
// `rofi -dmenu`, and on selection opens the bind's source line in the
// rice's editor (`zed --wait <file>:<line>` — the same convention as
// hyprland.conf's `$editor`).
//
// Four deliberate design points:
//   * `$var` substitution ($mod, $key_mail, ...) is DISPLAY-ONLY. The
//     source files are never rewritten; editing happens through Zed.
//   * Substitution runs only AFTER both files are fully parsed: the
//     earlier file's binds may reference variables defined in the later
//     one (keybinds-extra.conf is parsed first yet uses hyprland.conf's
//     $mod), so displays are built in a second pass, not while parsing.
//   * rofi is spawned with pipe()+fork()+dup2()+execvp() — a plain
//     popen() is one-directional and can't collect the selected index,
//     and system() would pull a shell into the middle for no reason.
//   * No -theme flag and no colors here: rofi auto-loads
//     ~/.config/rofi/config.rasi, which owns all styling.
//
// The repo tracks ONLY this source file. 30-dotfiles.sh rebuilds the
// binary into ~/.config/rofi/ on every deploy (gitignored in-repo).

#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <regex>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

struct Bind {
    std::string file;  // config file this bind was parsed from
    int line;          // 1-indexed line number in that file
    // Raw fields exactly as written in the source line (unsubstituted):
    std::string mods, key, dispatcher, params;
};

std::string trim(const std::string& s) {
    constexpr char kWs[] = " \t\r\n";
    const auto first = s.find_first_not_of(kWs);
    if (first == std::string::npos) return {};
    return s.substr(first, s.find_last_not_of(kWs) - first + 1);
}

// Replace every `$name` found in `s` with vars[name]. Re-runs over the
// result a bounded number of times so a value that itself references
// another variable still resolves, while a cyclic reference terminates.
std::string substitute(std::string s,
                       const std::unordered_map<std::string, std::string>& vars) {
    static const std::regex var_re(R"(\$([A-Za-z_][A-Za-z0-9_]*))");
    for (int round = 0; round < 8; ++round) {
        std::string out;
        out.reserve(s.size());
        bool changed = false;
        std::size_t last = 0;
        for (std::sregex_iterator it(s.begin(), s.end(), var_re), end;
             it != end; ++it) {
            const std::smatch& m = *it;
            const auto pos = static_cast<std::size_t>(m.position(0));
            const auto len = static_cast<std::size_t>(m.length(0));
            out.append(s, last, pos - last);
            if (const auto found = vars.find(m[1].str()); found != vars.end()) {
                out += found->second;
                changed = true;
            } else {
                out.append(s, pos, len);  // unknown $name: leave untouched
            }
            last = pos + len;
        }
        out.append(s, last, std::string::npos);
        s = std::move(out);
        if (!changed) break;
    }
    return s;
}

// One substituted rofi row for `b`: the non-empty fields, comma-joined,
// mirroring the source line's own `MODS, KEY, DISPATCHER, PARAMS` shape.
std::string display_of(const Bind& b,
                       const std::unordered_map<std::string, std::string>& vars) {
    std::string display;
    for (const std::string& field : {b.mods, b.key, b.dispatcher, b.params}) {
        if (field.empty()) continue;
        if (!display.empty()) display += ", ";
        display += substitute(field, vars);
    }
    return display;
}

// Collect `$name = value` assignments and `bind*` lines from one config
// file, appending to `vars` / `binds`. A missing file is not fatal on its
// own; main() simply ends up with fewer (or zero) rows to show.
void parse_file(const std::string& path,
                std::unordered_map<std::string, std::string>& vars,
                std::vector<Bind>& binds) {
    static const std::regex assign_re(
        R"(^\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$)");
    // bind<flags> = MODS, KEY, DISPATCHER[, PARAMS]
    // Flags are open-ended (bind/binde/bindl/bindel/bindm/bindd/...) so a
    // newly added Hyprland variant still lists; anything bind-prefixed that
    // STILL doesn't match the full grammar warns on stderr below instead of
    // vanishing silently.
    static const std::regex bind_re(
        R"(^\s*bind[a-z]*\s*=\s*([^,]*),\s*([^,]*),\s*([^,]*)(?:,\s*(.*))?$)");

    std::ifstream in(path);
    if (!in) return;

    std::string raw;
    int lineno = 0;
    while (std::getline(in, raw)) {
        ++lineno;
        // Hyprland's comment handling is quote-aware in principle; this
        // simple cut at the first '#' is exact for every bind in this rice
        // (none carries a literal '#' in its params).
        if (const auto hash = raw.find('#'); hash != std::string::npos)
            raw.erase(hash);

        std::smatch m;
        if (std::regex_match(raw, m, assign_re)) {
            vars[m[1].str()] = trim(m[2].str());  // last definition wins
            continue;
        }
        if (std::regex_match(raw, m, bind_re)) {
            Bind b;
            b.file = path;
            b.line = lineno;
            b.mods = trim(m[1].str());
            b.key = trim(m[2].str());
            b.dispatcher = trim(m[3].str());
            b.params = (m.size() > 4 && m[4].matched) ? trim(m[4].str()) : "";
            binds.push_back(std::move(b));
            continue;
        }
        // Starts with "bind" but doesn't match the grammar (e.g. a bindd
        // description with a comma, or a future variant): say so on stderr
        // (lands in Hyprland's log) instead of dropping the row silently.
        // A '{' means it's a `binds {}` settings block — not a keybind.
        if (const std::string t = trim(raw);
            t.rfind("bind", 0) == 0 && t.find('{') == std::string::npos) {
            std::cerr << "keybind-menu: " << path << ':' << lineno
                      << ": unrecognized bind line, skipped: " << t << '\n';
        }
    }
}

bool write_all(int fd, const char* data, std::size_t len) {
    while (len > 0) {
        const ssize_t n = ::write(fd, data, len);
        if (n < 0) {
            if (errno == EINTR) continue;
            return false;
        }
        data += n;
        len -= static_cast<std::size_t>(n);
    }
    return true;
}

int reap(pid_t pid) {
    int status = 0;
    while (::waitpid(pid, &status, 0) < 0)
        if (errno != EINTR) return -1;
    return status;
}

// Spawn `rofi -dmenu -p "keybinds" -format i`, feed it `lines` on stdin,
// and return whatever it prints on stdout (empty when cancelled).
// Returns false only on a real spawn/pipe failure.
bool rofi_query(const std::vector<std::string>& lines, std::string& out) {
    int to_child[2];    // parent writes -> rofi stdin
    int from_child[2];  // rofi stdout -> parent reads
    if (::pipe(to_child) < 0 || ::pipe(from_child) < 0) {
        std::cerr << "keybind-menu: pipe(): " << std::strerror(errno) << '\n';
        return false;
    }

    const pid_t pid = ::fork();
    if (pid < 0) {
        std::cerr << "keybind-menu: fork(): " << std::strerror(errno) << '\n';
        return false;
    }
    if (pid == 0) {
        ::dup2(to_child[0], STDIN_FILENO);
        ::dup2(from_child[1], STDOUT_FILENO);
        ::close(to_child[0]);
        ::close(to_child[1]);
        ::close(from_child[0]);
        ::close(from_child[1]);
        const char* argv[] = {"rofi", "-dmenu", "-p", "keybinds",
                              "-format", "i", nullptr};
        ::execvp(argv[0], const_cast<char* const*>(argv));
        std::cerr << "keybind-menu: exec rofi: " << std::strerror(errno) << '\n';
        ::_exit(127);
    }

    ::close(to_child[0]);
    ::close(from_child[1]);

    // Feed the whole list, then read rofi's one-line answer. The list is a
    // few KB at most, and rofi can't write a selection before a human picks
    // one, so there is no read/write interleaving to deadlock regardless of
    // exactly when rofi drains its stdin.
    bool sent = true;
    for (const std::string& line : lines) {
        sent = write_all(to_child[1], line.data(), line.size()) &&
               write_all(to_child[1], "\n", 1);
        if (!sent) break;
    }
    ::close(to_child[1]);

    char buf[4096];
    for (;;) {
        const ssize_t n = ::read(from_child[0], buf, sizeof buf);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;
        out.append(buf, static_cast<std::size_t>(n));
    }
    ::close(from_child[0]);
    reap(pid);

    if (!sent) {
        std::cerr << "keybind-menu: failed to feed rofi (is rofi installed?)\n";
        return false;
    }
    return true;
}

// Open `file:line` in the rice's editor: `zed --wait` (see hyprland.conf
// `$editor`). Blocks until the edit finishes, like a normal $EDITOR call.
bool open_in_editor(const std::string& file, int line) {
    const std::string target = file + ":" + std::to_string(line);
    const pid_t pid = ::fork();
    if (pid < 0) {
        std::cerr << "keybind-menu: fork(): " << std::strerror(errno) << '\n';
        return false;
    }
    if (pid == 0) {
        const char* argv[] = {"zed", "--wait", target.c_str(), nullptr};
        ::execvp(argv[0], const_cast<char* const*>(argv));
        std::cerr << "keybind-menu: exec zed: " << std::strerror(errno) << '\n';
        ::_exit(127);
    }
    const int status = reap(pid);
    if (status == -1 || !WIFEXITED(status) || WEXITSTATUS(status) == 127) {
        std::cerr << "keybind-menu: zed did not run cleanly\n";
        return false;
    }
    return true;
}

}  // namespace

int main() {
    // If rofi goes away mid-write, write() must fail with EPIPE, not kill
    // this process with SIGPIPE — the error path below reports it.
    std::signal(SIGPIPE, SIG_IGN);

    const char* home = std::getenv("HOME");
    if (home == nullptr || *home == '\0') {
        std::cerr << "keybind-menu: $HOME is not set\n";
        return 1;
    }

    std::unordered_map<std::string, std::string> vars;
    std::vector<Bind> binds;
    const std::string extra = std::string(home) + "/.config/hypr/keybinds-extra.conf";
    const std::string main_conf = std::string(home) + "/.config/hypr/hyprland.conf";
    parse_file(extra, vars, binds);
    parse_file(main_conf, vars, binds);
    if (binds.empty()) {
        std::cerr << "keybind-menu: parsed 0 binds from " << extra << " and "
                  << main_conf << " — check those files exist\n";
        return 0;  // still not an error: nothing to show, nothing to edit
    }

    // Display strings are built only now (see header): binds[i] below and
    // lines[i] here stay index-aligned by construction. (rofi's -format i
    // returns this same i.)
    std::vector<std::string> lines;
    lines.reserve(binds.size());
    for (const Bind& b : binds) lines.push_back(display_of(b, vars));

    std::string answer;
    if (!rofi_query(lines, answer)) return 1;

    answer = trim(answer);
    if (answer.empty()) return 0;  // Esc / cancelled: no error, no output

    char* endp = nullptr;
    errno = 0;
    const long idx = std::strtol(answer.c_str(), &endp, 10);
    if (errno != 0 || endp == answer.c_str() || *endp != '\0' ||
        idx < 0 || static_cast<std::size_t>(idx) >= binds.size()) {
        return 0;  // e.g. rofi's -1 for typed-but-unmatched text
    }

    const Bind& b = binds[static_cast<std::size_t>(idx)];
    if (!open_in_editor(b.file, b.line)) return 1;
    return 0;
}
