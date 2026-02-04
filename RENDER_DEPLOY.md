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

The `render.yaml` Blueprint deploys a single Ghost web service using the official Ghost Docker image (`ghost:5-alpine`).

**Key features:**
- Uses the official Ghost Docker image for reliability
- SQLite database for simplicity (stored on persistent disk)
- Persistent disk for content (images, themes, uploads, database)
- Health check endpoint configured
- Port 10000 (Render's default)

## Database

This configuration uses **SQLite** by default, which is suitable for:
- Personal blogs
- Small to medium traffic sites
- Development and testing

The SQLite database is stored on the persistent disk at `/var/lib/ghost/content/data/ghost.db`.

### Using MySQL Instead

For higher traffic sites or production deployments, you may want to use MySQL. You can use an external MySQL-compatible database:

- [PlanetScale](https://planetscale.com/) - Serverless MySQL
- [TiDB Cloud](https://tidbcloud.com/) - MySQL-compatible, free tier available
- [AWS RDS](https://aws.amazon.com/rds/mysql/) - Managed MySQL
- [DigitalOcean Managed Databases](https://www.digitalocean.com/products/managed-databases-mysql)

Update the database environment variables in `render.yaml`:

```yaml
- key: database__client
  value: mysql2
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

Ghost content (images, themes, files, SQLite database) is stored on a Render Disk mounted at `/var/lib/ghost/content`. The default size is 10GB but can be increased in the Render dashboard.

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

The deployment uses the `ghost:5-alpine` Docker image. To upgrade:

1. Update the `FROM` line in `Dockerfile.render` to a newer Ghost version
2. Commit and push the changes
3. Render will automatically rebuild and deploy

## Troubleshooting

### Container Startup Issues

- Check the Render logs for error messages
- Ensure the `url` environment variable is set correctly
- Ghost may take 1-2 minutes to start on first deployment (database initialization)

### Health Check Failures

- Ghost may take 1-2 minutes to start on first deployment
- The health check has a 60-second start period to allow for initialization
- Check application logs for startup errors

### Content Not Persisting

- Verify the disk is properly mounted at `/var/lib/ghost/content`
- Check disk usage in Render dashboard (may need to increase size)

### Database Issues

- For SQLite: Check that the `/var/lib/ghost/content/data/` directory exists
- For MySQL: Verify connection settings and that the database is accessible

## Resources

- [Ghost Documentation](https://ghost.org/docs/)
- [Ghost Configuration](https://ghost.org/docs/config/)
- [Official Ghost Docker Image](https://hub.docker.com/_/ghost)
- [Render Documentation](https://render.com/docs)
- [Render Blueprints](https://render.com/docs/blueprint-spec)

## Support

- [Ghost Forum](https://forum.ghost.org)
- [Render Community](https://community.render.com)
- [GitHub Issues](https://github.com/TryGhost/Ghost/issues)
