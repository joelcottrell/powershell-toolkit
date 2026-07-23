# Repository Integration

This project is prepared for the existing repository structure:

```text
powershell-toolkit/
└── VMWare/
    └── PowerCLI/
        └── Networking/
            └── PortGroup-Provisioning/
```

## Upload through GitHub.com

1. Extract the ZIP file locally.
2. Open the root of the `joelcottrell/powershell-toolkit` repository.
3. Select **Add file**, then **Upload files**.
4. Drag the extracted `VMWare` folder into the upload area.
5. Confirm that GitHub shows the files under `VMWare/PowerCLI/Networking/PortGroup-Provisioning`.
6. Commit to a feature branch or directly to the selected branch, depending on repository policy.

GitHub merges the uploaded `VMWare` folder with the existing folder instead of replacing unrelated content.

## Suggested commit message

```text
Add VMware port group provisioning project
```

## Suggested main README addition

Add the following beneath the VMware section of the repository README:

```markdown
### VMware Networking

- [Port Group Provisioning](VMWare/PowerCLI/Networking/PortGroup-Provisioning/) - Creates standard vSwitches, standard port groups, and distributed port groups from validated CSV configuration files.
```

## Suggested repository structure update

```text
├── VMWare/PowerCLI/
│   └── Networking/
│       └── PortGroup-Provisioning/
```
