harbor.lab.local → 172.16.100.50:80 (Harbor)
git-lab.lab.local → 172.16.100.40:8181 (GitLab)
taiga.lab.local → 172.16.100.20:9000 (Taiga)
edgedoc.lab.local → 172.16.100.20:8080 (HedgeDoc)
grafana.lab.local → 172.16.100.60:3000
prometheus.lab.local → 172.16.100.60:9090
alertmanager.lab.local → 172.16.100.60:9093
portainer.lab.local → 172.16.100.50:9000

Exemple :
ssh -N -L 8006:127.0.0.1:8006 -J james@10.8.0.30 root@10.250.250.4 