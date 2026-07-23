# Repository Integration

> **Status: historical.** These were the one-time instructions for adding this project to
> the repository. It has since been integrated and relocated by the repository
> restructure. The paths below reflect the current layout; the upload procedure itself is
> retained only for reference and is no longer needed.

This project lives at:

```text
powershell-toolkit/
└── Virtualization/
    └── VMware/
        └── PowerCLI/
            └── Networking/
                └── PortGroup-Provisioning/
```

## Upload through GitHub.com

1. Extract the ZIP file locally.
2. Open the root of the `joelcottrell/powershell-toolkit` repository.
3. Select **Add file**, then **Upload files**.
4. Drag the extracted `Virtualization` folder into the upload area.
5. Confirm that GitHub shows the files under
   `Virtualization/VMware/PowerCLI/Networking/PortGroup-Provisioning`.
6. Commit to a feature branch or directly to the selected branch, depending on repository
   policy.

GitHub merges the uploaded `Virtualization` folder with the existing folder instead of
replacing unrelated content.

## Suggested commit message

```text
Add VMware port group provisioning project
```

## Repository README entry

The project is indexed from the
[Networking category README](../../README.md) and featured in the
[repository root README](../../../../../../README.md).
