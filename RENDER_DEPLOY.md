# Deploying Ghost on Render

This guide explains how to deploy Ghost on [Render](https://render.com) using the included `render.yaml` Blueprint configuration.

## Prerequisites

- A [Render account](https://dashboard.render.com/register)
- A fork or clone of this Ghost repository

## Quick Deploy

### Option 1: One-Click Deploy with Blueprint

1. Click the button below to deploy Ghost to Render:

   [![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

2. In the Render dashboard, you'll be prompted to:
   - Connect your GitHub/GitLab repository
   - Set required environment variables (see below)

3. Click **Apply** to start the deployment

### Option 2: Manual Setup

1. Create a new **Blueprint** in your Render dashboard
2. Connect your repository containing this Ghost codebase
3. Render will automatically detect the `render.yaml` file
4. Configure the required environment variables
5. Deploy

## Configuration

### Required Environment Variables

After deployment, you **must** configure these variables in the Render dashboard:

| Variable | Description | Example |
|----------|-------------|---------|
| `url` | Your Ghost site's public URL | `https://ghost-xxxx.onrender.com` or `https://yourdomain.com` |

### Optional Environment Variables

#### Mail Configuration

Ghost requires mail configuration to send password resets, member emails, etc.

| Variable | Description | Example |
|----------|-------------|---------|
| `mail__options__host` | SMTP server host | `smtp.mailgun.org` |
| `mail__options__port` | SMTP server port | `587` |
| `mail__options__secure` | Use TLS | `true` |
| `mail__options__auth__user` | SMTP username | `postmaster@mg.yourdomain.com` |
| `mail__options__auth__pass` | SMTP password | `your-smtp-password` |

**Recommended Mail Providers:**
- [Mailgun](https://www.mailgun.com/) - Ghost's recommended provider
- [SendGrid](https://sendgrid.com/)
- [Amazon SES](https://aws.amazon.com/ses/)

#### Stripe Integration (Memberships)

For paid memberships and subscriptions:

| Variable | Description |
|----------|-------------|
| `stripe__secretKey` | Your Stripe secret key (`sk_live_...`) |
| `stripe__publicKey` | Your Stripe publishable key (`pk_live_...`) |

## Architecture

The `render.yaml` Blueprint deploys:

1. **Ghost Web Service** - The main Ghost application
   - Node.js runtime
   - Persistent disk for content (images, themes, uploads)
   - Auto-scaling available on higher plans

2. **MySQL Private Service** - Database backend
   - MySQL 8.0 running in Docker
   - Persistent disk for data storage
   - Only accessible within your Render private network

## Alternative: SQLite Configuration

For simpler deployments or testing, you can use SQLite instead of MySQL. This eliminates the need for a separate database service but is **not recommended for production** due to performance and concurrency limitations.

To use SQLite, modify `render.yaml`:

```yaml
services:
  - type: web
    name: ghost
    # ... other config ...
    envVars:
      # Replace MySQL config with SQLite
      - key: database__client
        value: sqlite3
      - key: database__connection__filename
        value: /var/data/ghost/content/data/ghost.db
```

Then remove the MySQL private service section.

## Alternative: External MySQL

Instead of running MySQL on Render, you can use an external MySQL-compatible database:

- [PlanetScale](https://planetscale.com/) - Serverless MySQL
- [TiDB Cloud](https://tidbcloud.com/) - MySQL-compatible, free tier available
- [AWS RDS](https://aws.amazon.com/rds/mysql/) - Managed MySQL
- [DigitalOcean Managed Databases](https://www.digitalocean.com/products/managed-databases-mysql)

Update the database environment variables accordingly:

```yaml
- key: database__connection__host
  value: your-external-host.com
- key: database__connection__port
  value: "3306"
- key: database__connection__user
  value: your-username
- key: database__connection__password
  value: your-password
- key: database__connection__database
  value: ghost
```

## Persistent Storage

Ghost content (images, themes, files) is stored on a Render Disk mounted at `/var/data/ghost/content`. The default size is 10GB but can be increased in the Render dashboard.

**Important:** Render Disks are tied to a single service instance. For high-availability deployments, consider using external object storage like:
- AWS S3
- DigitalOcean Spaces
- Cloudflare R2

## Custom Domain

1. In your Render dashboard, go to your Ghost service
2. Click **Settings** > **Custom Domains**
3. Add your domain and follow DNS configuration instructions
4. Update the `url` environment variable to match your custom domain

## Upgrading Ghost

To upgrade Ghost:

1. Pull the latest changes from the Ghost repository
2. Push to your deployment branch
3. Render will automatically rebuild and deploy

## Troubleshooting

### Build Failures

- Ensure Node.js version 22 is available (set via `NODE_VERSION` env var)
- Check build logs for yarn/npm errors
- Verify all dependencies are properly listed in `package.json`

### Database Connection Issues

- Verify the MySQL service is running (check service logs)
- Ensure environment variables are correctly set
- MySQL needs 30-60 seconds to initialize on first deployment

### Content Not Persisting

- Verify the disk is properly mounted at `/var/data/ghost/content`
- Check disk usage in Render dashboard (may need to increase size)

### Health Check Failures

- Ghost may take 1-2 minutes to start on first deployment
- Increase health check timeout if needed
- Check application logs for startup errors

## Resources

- [Ghost Documentation](https://ghost.org/docs/)
- [Ghost Configuration](https://ghost.org/docs/config/)
- [Render Documentation](https://render.com/docs)
- [Render Blueprints](https://render.com/docs/blueprint-spec)

## Support

- [Ghost Forum](https://forum.ghost.org)
- [Render Community](https://community.render.com)
- [GitHub Issues](https://github.com/TryGhost/Ghost/issues)
