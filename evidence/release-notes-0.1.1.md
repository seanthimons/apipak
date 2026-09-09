Generated output now uses an ownership header that allows Air to format it, avoiding Air 0.9.0's generated-file skip directive and unstable Windows line endings. Legacy ownership and readiness headers remain recognized.

Source: 8627b8176969476a983e080b06753cf1bb679f60.
Validation: all 16 acceptance scripts in Windows R CMD check (Status OK), plus Windows and Ubuntu CI: https://github.com/seanthimons/apipak/actions/runs/34362224756.

Asset: apipak_0.1.1.tar.gz
SHA-256: 48dd1b531ab29d2d6a86fe7a146b218b66a46d49c2af017166dc5ad67985baf9

This replaces the development pin after checksum verification. It does not release ComptoxR or change the Natural Products schema-only scope.
