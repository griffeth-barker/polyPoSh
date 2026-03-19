![](/assets/polyPoSh-logo-x500-nobg.png)  
  
# polyPoSh
A shell script for installing the appropriate PowerShell package based on Linux distribution and architecture.

# Getting Started
You can run the script immediately using the following command:
```shell
curl -sSL https://polypo.sh/install | bash
```

The SHA256 hash of the current script is: `9A07746F76EBD30E676F4BC84945349813C480164E70F49E4237EEE2C9AA1F94`  
  
> **⚠️  Warning**
>   
> Piping a script directly from a URL into a shell (e.g., `curl | bash`) is a convenient way to install software, but it carries inherent security risks. By doing so, you are executing unverified code with the privileges of your current user or sudo.
>
> Before running the one-liner above, please ensure you:  
>    - **Trust the source:** Only download scripts from repositories and domains you trust.  
>    - **Inspect the code:** Download the script first (`curl -sSL -o install.sh https://polypo.sh/install`) and review the contents before execution.  
>    - **Understand the impact:** Be aware that the script may modify system configurations, install packages, or require elevated privileges.
>  
> Use this tool at your own risk. The maintainers are not responsible for any system instability or security compromises resulting from the use of this installation method.

# Contributing
If you'd like to contribute, please do so! Check out [CONTRIBUTING](/docs/contributing.md).  
Feedback and contributions are always welcome via issues and pull requests.
  
# Feedback and Support
Limited documentation is available in [the docs](/docs).  
This is an AI-assisted open source side project and no guarantee of functionality or support is offered.
