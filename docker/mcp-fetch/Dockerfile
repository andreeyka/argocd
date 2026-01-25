# MCP Fetch Server with StreamableHTTP transport
# Based on: https://pypi.org/project/mcp-fetch-streamablehttp-server/

FROM python:3.12-slim

# Install the package
RUN pip install --no-cache-dir mcp-fetch-streamablehttp-server

# Set environment variables
ENV MCP_SERVER_NAME=mcp-fetch
ENV MCP_SERVER_VERSION=1.0.0
ENV MCP_PROTOCOL_VERSION=2025-06-18
ENV HOST=0.0.0.0
ENV PORT=3000

# Expose the port
EXPOSE 3000

# Run the server
CMD ["python", "-m", "mcp_fetch_streamablehttp_server"]
