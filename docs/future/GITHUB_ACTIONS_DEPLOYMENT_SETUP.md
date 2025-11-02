# Securing GitHub Actions Deployment

## 🔐 **Secure Deployment Setup Guide**

This guide shows how to securely configure the deployment webhook for GitHub Actions.

---

## 🏗️ **Architecture**

```
GitHub Actions → Webhook → Rails Controller → Background Job → Deployment
     ↓              ↓              ↓                ↓              ↓
  (Push)      (Signed)       (Verified)      (Queued)        (Executed)
```

**Security Layers**:
1. ✅ GitHub webhook signature verification (HMAC-SHA256)
2. ✅ Custom deploy token authentication
3. ✅ Background job execution (prevents timeouts)
4. ✅ Detailed logging of all attempts
5. ✅ Error handling and retry logic

---

## 🔧 **Setup Instructions**

### **Step 1: Generate Secrets**

Generate two strong random secrets:

```bash
# On your local machine or server
# Generate GitHub webhook secret
ruby -r securerandom -e 'puts SecureRandom.hex(32)'
# Example: a3f5c8e9d2b1f4e7c0a6b8d3e1f2c4a5b6d7e8f9a0b1c2d3e4f5g6h7i8j9k0

# Generate deploy token
ruby -r securerandom -e 'puts SecureRandom.hex(32)'
# Example: z1x2c3v4b5n6m7q8w9e0r1t2y3u4i5o6p7a8s9d0f1g2h3j4k5l6z7x8c9v0
```

---

### **Step 2: Configure Environment Variables**

#### **On Production Server** (using dotenv or .env file):

```bash
# /home/rails/morfeo/.env.production
GITHUB_WEBHOOK_SECRET=a3f5c8e9d2b1f4e7c0a6b8d3e1f2c4a5b6d7e8f9a0b1c2d3e4f5g6h7i8j9k0
DEPLOY_SECRET_TOKEN=z1x2c3v4b5n6m7q8w9e0r1t2y3u4i5o6p7a8s9d0f1g2h3j4k5l6z7x8c9v0
```

**Important**: Never commit these secrets to git!

#### **Restart Rails** after adding secrets:

```bash
sudo systemctl restart morfeo-production
# OR
touch tmp/restart.txt
```

---

### **Step 3: Configure GitHub Repository**

#### **A. Set up Webhook** (For direct webhook approach):

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. **Payload URL**: `https://your-domain.com/home/deploy`
4. **Content type**: `application/json`
5. **Secret**: (paste your `GITHUB_WEBHOOK_SECRET`)
6. **Which events**: Just the push event
7. **Active**: ✓ Checked
8. Click "Add webhook"

#### **B. Set up GitHub Actions** (Recommended):

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Trigger Production Deployment
        run: |
          curl -X POST \
            -H "Content-Type: application/json" \
            -H "X-Hub-Signature-256: sha256=$(echo -n '{}' | openssl dgst -sha256 -hmac "${{ secrets.GITHUB_WEBHOOK_SECRET }}" | cut -d' ' -f2)" \
            -H "X-Deploy-Token: ${{ secrets.DEPLOY_SECRET_TOKEN }}" \
            -d '{"ref": "${{ github.ref }}", "repository": "${{ github.repository }}", "pusher": "${{ github.actor }}"}' \
            https://your-domain.com/home/deploy
```

#### **C. Add Secrets to GitHub**:

1. Go to: Repository → Settings → Secrets and variables → Actions
2. Add two secrets:
   - Name: `GITHUB_WEBHOOK_SECRET`, Value: (your secret)
   - Name: `DEPLOY_SECRET_TOKEN`, Value: (your token)

---

### **Step 4: Test the Setup**

#### **Test 1: Invalid Request (Should Fail)**

```bash
curl -X POST https://your-domain.com/home/deploy
# Expected: 401 Unauthorized
```

#### **Test 2: Valid Request (Should Succeed)**

```bash
# Generate valid signature
WEBHOOK_SECRET="your_github_webhook_secret"
DEPLOY_TOKEN="your_deploy_token"
PAYLOAD='{"test": true}'

SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" | cut -d' ' -f2)

curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
  -H "X-Deploy-Token: $DEPLOY_TOKEN" \
  -d "$PAYLOAD" \
  https://your-domain.com/home/deploy

# Expected: {"status":"accepted","message":"Deployment started successfully","timestamp":"..."}
```

---

## 📊 **Monitoring Deployments**

### **Check Logs**

```bash
# On production server
tail -f log/production.log | grep -i deploy

# Example output:
# Authorized deployment triggered from GitHub Actions
# Starting deployment process...
# Deployment: Git Pull...
# Deployment: Git Pull ✓
# Deployment: Bundle Install...
# Deployment: Bundle Install ✓
# ...
# Deployment completed successfully in 45.3s
```

### **Check Sidekiq Dashboard**

Visit: `https://your-domain.com/sidekiq` (if enabled)

Check for `DeploymentJob` in the queue.

---

## 🚨 **Security Features**

### **1. GitHub Webhook Signature Verification**

Uses HMAC-SHA256 to verify requests come from GitHub:

```ruby
def verify_github_signature
  signature = request.headers['X-Hub-Signature-256']
  payload_body = request.body.read
  
  expected_signature = 'sha256=' + OpenSSL::HMAC.hexdigest(
    OpenSSL::Digest.new('sha256'),
    ENV['GITHUB_WEBHOOK_SECRET'],
    payload_body
  )
  
  Rack::Utils.secure_compare(signature, expected_signature)
end
```

### **2. Custom Deploy Token**

Additional layer of security:

```ruby
def valid_deploy_token?
  deploy_token = request.headers['X-Deploy-Token']
  Rack::Utils.secure_compare(deploy_token, ENV['DEPLOY_SECRET_TOKEN'])
end
```

### **3. Timing-Safe Comparison**

Uses `Rack::Utils.secure_compare` to prevent timing attacks.

### **4. Detailed Logging**

All deployment attempts are logged:
- ✅ Successful deployments
- ❌ Failed authentication attempts (with IP)
- ⚠️ Deployment errors

---

## 🔍 **Troubleshooting**

### **Issue: 401 Unauthorized**

**Cause**: GitHub signature verification failed

**Solutions**:
1. Check `GITHUB_WEBHOOK_SECRET` matches in GitHub and server
2. Verify webhook is sending `X-Hub-Signature-256` header
3. Check logs for specific error

```bash
grep "Unauthorized deployment attempt" log/production.log
```

### **Issue: 403 Forbidden**

**Cause**: Deploy token verification failed

**Solutions**:
1. Check `DEPLOY_SECRET_TOKEN` is set on server
2. Verify GitHub Actions secret `DEPLOY_SECRET_TOKEN` matches
3. Check `X-Deploy-Token` header is being sent

```bash
grep "Invalid deploy token" log/production.log
```

### **Issue: Deployment Hangs**

**Cause**: Background job not processing

**Solutions**:
1. Check Sidekiq is running: `ps aux | grep sidekiq`
2. Check Redis is running: `redis-cli ping`
3. Restart Sidekiq: `sudo systemctl restart sidekiq`

```bash
# Check job queue
RAILS_ENV=production bin/rails runner "puts Sidekiq::Queue.new('critical').size"
```

### **Issue: Deployment Fails at Specific Step**

**Solutions**:
1. Check logs for specific error
2. Run the failed command manually to debug
3. Check file permissions

```bash
# Example: Test git pull manually
cd /home/rails/morfeo
sudo -u rails git pull
```

---

## 🎯 **Best Practices**

### **✅ DO**

1. ✅ Use strong random secrets (32+ characters)
2. ✅ Never commit secrets to git
3. ✅ Rotate secrets every 90 days
4. ✅ Monitor deployment logs regularly
5. ✅ Test deployments in staging first
6. ✅ Use HTTPS for webhook URL
7. ✅ Keep deployment steps idempotent
8. ✅ Add deployment notifications (Slack/Discord)

### **❌ DON'T**

1. ❌ Share deployment secrets in chat/email
2. ❌ Use weak or predictable tokens
3. ❌ Skip signature verification
4. ❌ Run deployments as root user
5. ❌ Deploy without testing
6. ❌ Ignore deployment errors
7. ❌ Use HTTP (unencrypted) webhooks

---

## 📈 **Advanced Configuration**

### **Add Slack Notifications**

In `DeploymentJob`:

```ruby
def notify_deployment_success(duration)
  webhook_url = ENV['SLACK_DEPLOY_WEBHOOK']
  return unless webhook_url
  
  message = {
    text: "✅ Deployment successful in #{duration}s",
    attachments: [{
      color: 'good',
      fields: [
        { title: 'Environment', value: 'Production', short: true },
        { title: 'Duration', value: "#{duration}s", short: true }
      ]
    }]
  }
  
  HTTP.post(webhook_url, json: message)
end
```

### **Add IP Whitelist**

For extra security, whitelist GitHub IPs:

```ruby
# config/initializers/github_ips.rb
GITHUB_WEBHOOK_IPS = %w[
  140.82.112.0/20
  143.55.64.0/20
  185.199.108.0/22
  192.30.252.0/22
].freeze

# In controller
def deploy
  unless github_ip_allowed?
    Rails.logger.warn "Deploy attempt from non-GitHub IP: #{request.remote_ip}"
    return head :forbidden
  end
  # ... rest of code
end

def github_ip_allowed?
  GITHUB_WEBHOOK_IPS.any? do |range|
    IPAddr.new(range).include?(request.remote_ip)
  end
end
```

### **Add Deployment Locking**

Prevent concurrent deployments:

```ruby
# In DeploymentJob
def perform
  Rails.cache.fetch('deployment_in_progress', expires_in: 10.minutes) do
    raise 'Deployment already in progress'
  end
  
  Rails.cache.write('deployment_in_progress', true, expires_in: 10.minutes)
  
  begin
    # ... deployment steps ...
  ensure
    Rails.cache.delete('deployment_in_progress')
  end
end
```

---

## ✅ **Security Checklist**

Before going to production, verify:

- [ ] `GITHUB_WEBHOOK_SECRET` is set and strong (32+ chars)
- [ ] `DEPLOY_SECRET_TOKEN` is set and strong (32+ chars)
- [ ] Secrets are NOT in git repository
- [ ] Secrets are in `.env.production` or environment
- [ ] GitHub webhook is configured with correct secret
- [ ] GitHub Actions has both secrets configured
- [ ] HTTPS is enabled (not HTTP)
- [ ] Tested with invalid request (should fail)
- [ ] Tested with valid request (should succeed)
- [ ] Logs show successful authentication
- [ ] Background job processes correctly
- [ ] Deployment steps execute in correct order
- [ ] Server restarts after deployment

---

## 📚 **Resources**

- [GitHub Webhooks Documentation](https://docs.github.com/en/webhooks)
- [Validating Webhook Deliveries](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Rails Background Jobs](https://guides.rubyonrails.org/active_job_basics.html)

---

## 🎉 **Summary**

✅ **Two-layer authentication** (GitHub signature + custom token)  
✅ **Background job execution** (no timeouts)  
✅ **Comprehensive logging** (all attempts tracked)  
✅ **Error handling & retry** (automatic recovery)  
✅ **Production-ready** (secure & reliable)

---

**Security Status**: ✅ **PRODUCTION READY**

Your deployment webhook is now properly secured for GitHub Actions!

