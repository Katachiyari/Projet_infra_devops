# Security Checklist: Taiga & EdgeDoc

## 1. Docker Image Scanning
- [ ] Use only official images
- [ ] Scan all images with Trivy before deployment

## 2. Network Security
- [ ] Restrict access with UFW (allow only required ports)
- [ ] Enforce HTTPS via Nginx reverse-proxy
- [ ] Isolate containers with Docker networks

## 3. Application Security
- [ ] Set strong admin credentials
- [ ] Disable default/demo accounts
- [ ] Apply all security patches

## 4. Nginx Security Headers
- [ ] Add X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, Content-Security-Policy

## 5. Monitoring & Logging
- [ ] Enable Prometheus metrics
- [ ] Forward logs to central system

## 6. Secrets Management
- [ ] Store secrets outside version control
- [ ] Use Ansible Vault for sensitive variables

---

## Authors
DevSecOps Lab – Mission 4
