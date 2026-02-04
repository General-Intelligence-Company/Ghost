# Use official Ghost image for production deployment
FROM ghost:5-alpine

# Set environment variables for production
ENV NODE_ENV=production

# Ghost listens on port 2368 by default, but Render expects 10000
ENV PORT=10000
ENV server__port=10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/ghost/api/admin/site/ || exit 1

EXPOSE 10000

# Start Ghost
CMD ["node", "current/index.js"]
