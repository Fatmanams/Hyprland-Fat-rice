// keybind-menu.cpp — rofi-based Hyprland keybind viewer/editor.
//
// Parses `bind*` lines out of ~/.config/hypr/keybinds-extra.conf and
// ~/.config/hypr/hyprland.conf (in that order), lists them in
// `rofi -dmenu`, and on selection opens the bind's source line in
// $editor. EDITS LAND ON THE REPO CHECKOUT: 30-dotfiles.sh bakes the
// repo path into the binary with -DRICE_REPO, and the live ~/.config
// path is mapped back to $RICE_REPO/config/..., so a change made through
// the menu is a change git can see and the next deploy regenerates FROM
// (editing ~/.config/hypr/* directly would be silently overwritten).
//
// Deliberate design points:
//   * $var substitution ($mod, $key_mail, ...) is DISPLAY-ONLY. The
//     source files are never rewritten by this tool; editing happens in
//     the configured editor.
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
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

// 30-dotfiles.sh builds with -DRICE_REPO="\"/path/to/checkout\"" so an
// edit target can be mapped live-config -> tracked repo file. The #ifndef
// fallback keeps hand builds (and lint.yml's -fsyntax-only, which passes
// no -D) compiling; they just edit the deployed copy directly.
#ifndef RICE_REPO
#define RICE_REPO ""
#endif

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

// Map a deployed config path back to its source file in this repo:
//   <home>/.config/<rest>   ->   <RICE_REPO>/config/<rest>
// 30-dotfiles.sh `cp -a`'s the tree verbatim, so relative layout (and line
// numbers, while the deploy is current) match. Edit the repo file when it
// exists there — otherwise edits would die with the next deploy. Falls
// back to the deployed path when built without -DRICE_REPO, when the path
// isn't under ~/.config, or when the repo file is gone (source deleted).
std::string edit_target(const std::string& deployed_path,
                        const std::string& home) {
    if (RICE_REPO[0] == '\0') return deployed_path;  // hand-built binary
    const std::string prefix = home + "/.config/";
    if (deployed_path.compare(0, prefix.size(), prefix) != 0)
        return deployed_path;
    const std::string repo_path =
        std::string(RICE_REPO) + "/config/" + deployed_path.substr(prefix.size());
    std::ifstream probe(repo_path);
    return probe.good() ? repo_path : deployed_path;
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
        // execvp only resets caught handlers; SIG_IGN survives it. Give the
        // child the default SIGPIPE disposition none of this code changed.
        std::signal(SIGPIPE, SIG_DFL);
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
    const int status = reap(pid);

    if (!sent) {
        std::cerr << "keybind-menu: failed to feed rofi (is it installed?)\n";
        return false;
    }
    // Exit 127 = the child's execvp failed: rofi is not on PATH. Without
    // this check a missing rofi reads back as "cancelled" and exits 0.
    if (status == -1 || !WIFEXITED(status) || WEXITSTATUS(status) == 127) {
        std::cerr << "keybind-menu: could not run rofi (is it installed?)\n";
        return false;
    }
    return true;
}

// Open `file:line` in the configured $editor ("zed --wait" in this rice —
// parsed from hyprland.conf like every other variable, default if unset).
// Blocks until the edit finishes, like a normal $EDITOR call.
bool open_in_editor(const std::string& file, int line,
                    const std::unordered_map<std::string, std::string>& vars) {
    std::string editor = "zed --wait";
    if (const auto it = vars.find("editor"); it != vars.end()) {
        const std::string v = trim(it->second);
        if (!v.empty()) editor = v;
    }
    // $editor is a command line ("zed --wait"), not an argv; split on
    // whitespace. Values here are simple flags, no quoting/escaping needed.
    std::vector<std::string> argv_s;
    {
        std::istringstream split(editor);
        for (std::string word; split >> word;) argv_s.push_back(word);
    }
    if (argv_s.empty()) return false;
    argv_s.push_back(file + ":" + std::to_string(line));

    const pid_t pid = ::fork();
    if (pid < 0) {
        std::cerr << "keybind-menu: fork(): " << std::strerror(errno) << '\n';
        return false;
    }
    if (pid == 0) {
        std::signal(SIGPIPE, SIG_DFL);  // see rofi_query for why
        std::vector<const char*> argv;
        for (const std::string& a : argv_s) argv.push_back(a.c_str());
        argv.push_back(nullptr);
        ::execvp(argv[0], const_cast<char* const*>(argv.data()));
        std::cerr << "keybind-menu: exec " << argv[0] << ": "
                  << std::strerror(errno) << '\n';
        ::_exit(127);
    }
    const int status = reap(pid);
    if (status == -1 || !WIFEXITED(status) || WEXITSTATUS(status) == 127) {
        std::cerr << "keybind-menu: editor did not run cleanly\n";
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
    // Edit the repo checkout's copy (see edit_target), line number
    // unchanged: cp -a deploys byte-identical files.
    if (!open_in_editor(edit_target(b.file, home), b.line, vars)) return 1;
    return 0;
}
