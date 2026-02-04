FROM ghost:latest

# Create content directory with proper structure
RUN mkdir -p /var/lib/ghost/content/data

# Set environment for production
ENV NODE_ENV=production

# Ghost runs on port 2368
EXPOSE 2368

# Default command - Ghost image handles this automatically
CMD ["node", "current/index.js"]
