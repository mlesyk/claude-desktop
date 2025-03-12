# SPECIAL INSTRUCTIONS FOR RUNNING MCP ON LINUX

Most MCP servers should run on Linux just fine, however there are some caveats like the lack of DISPLAY env variable that makes GUI based MCPs, like the browser based one, not work.

To address this, we have to manually add the DISPLAY env variable to the MCP server configuration, which on Linux resides in `~/.config/Claude/claude_desktop_config.json"`.
For example to run the Playwright MCP server, you would add the following configuration to the file:

```json
{
  "mcpServers": {
    "@executeautomation-playwright-mcp-server": {
      "command": "npx",
      "args": [
        "-y",
        "@executeautomation/playwright-mcp-server"
      ],
      "env": {
        "DISPLAY": ":0"
      }
    }
  }
}
```


# Installing a custom MCP server

```bash
mkdir my-mcp-server
cd my-mcp-server
uv init
# clone the modified mcp-python-sdk-linux
git clone https://github.com/emsi/mcp-python-sdk-linux
# add the linux mcp python-sdk to the project
uv add "./mcp-python-sdk-linux[cli]"

# Now create your custom mpc server in server.py file or copy one of the examples from the mcp-python-sdk-linux README.md

# install the server in claude-desktop app
uv run mcp install server.py
```

This will add the custom server to the claude-desktop app and you can now interact with it fromt he Claude Desktop app.