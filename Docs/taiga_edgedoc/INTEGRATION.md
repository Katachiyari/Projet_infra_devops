# Taiga & EdgeDoc Integration Guide

## Overview
This guide describes the integration of Taiga and EdgeDoc into the DevSecOps lab stack, covering:
- Reverse-proxy (Nginx) configuration
- DNS (Bind9) setup
- Security (Trivy, UFW, headers)
- Monitoring (Prometheus, Node Exporter)

## 1. Nginx Reverse-Proxy
- Add server blocks for Taiga and EdgeDoc
- Enforce HTTPS, security headers, and HTTP-to-HTTPS redirection

## 2. Bind9 DNS
- Create A records for taiga.lab.local and edgedoc.lab.local

## 3. Security
- Scan images with Trivy
- Restrict access with UFW
- Apply secure headers in Nginx

## 4. Monitoring
- Expose metrics endpoints
- Add targets to Prometheus config

---

## References
- [Nginx Role](../roles/nginx/)
- [Bind9 Role](../roles/bind9_docker/)
- [Monitoring Stack](../roles/monitoring/)

## Authors
DevSecOps Lab – Mission 4
