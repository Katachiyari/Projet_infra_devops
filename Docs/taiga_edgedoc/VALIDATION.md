# Validation Guide: Taiga & EdgeDoc

## 1. Service Availability
- [ ] Access Taiga at http://taiga.lab.local
- [ ] Access EdgeDoc at http://edgedoc.lab.local
- [ ] Validate HTTPS redirection and certificates

## 2. Functionality
- [ ] Create a project in Taiga
- [ ] Create and edit a document in EdgeDoc
- [ ] Test collaborative editing

## 3. Monitoring
- [ ] Check Prometheus targets for both services
- [ ] Validate Node Exporter metrics

## 4. Security
- [ ] Confirm Trivy scan results are clean
- [ ] Test UFW rules (only required ports open)
- [ ] Check Nginx security headers

## 5. Idempotence
- [ ] Re-run playbooks; ensure no unintended changes

---

## Authors
DevSecOps Lab – Mission 4
