"""Opening this file makes Zed download Pyright (background task)."""


def greet(name: str) -> str:
    return f"hello from Python, {name}"


def main() -> None:
    print(greet("Zed"))


if __name__ == "__main__":
    main()
