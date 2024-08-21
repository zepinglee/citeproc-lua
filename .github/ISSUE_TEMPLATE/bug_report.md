---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**Additional information**
- TeX distribution: [e.g. TeX Live 2022, MacTeX 2022, TeX Live 2022 on Overleaf]
- Package `citation-style-language` version: [e.g. v0.1.0, main branch]
- LaTeX engine: [e.g. `pdflatex` / `xelatex` / `lualatex`]

**To Reproduce**
```tex
\documentclass{article}

\begin{filecontents}[noheader, overwrite]{\jobname.json}
[
    {
        "id": "ITEM-1",
        "type": "book",
        "author": [
            {
                "family": "D’Arcus",
                "given": "Bruce"
            }
        ],
        "issued": {
            "date-parts": [
                [
                    2005
                ]
            ]
        },
        "publisher": "Routledge",
        "title": "Boundaries of dissent: Protest and state power in the media age"
    }
]
\end{filecontents}

\usepackage[style=apa]{citation-style-language}
\addbibresource{\jobname.json}
\usepackage{hyperref}

\begin{document}
\cite{ITEM-1}
\printbibliography
\end{document}
```

**Screenshots**
If applicable, add screenshots to help explain your problem.
