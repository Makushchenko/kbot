helm install jenkins jenkins/jenkins
# --- Get your 'admin' user password by running:
kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
# --- Get the Jenkins URL to visit by running these commands in the same shell
# --- Login with the password from step 1 and the username: admin
echo http://127.0.0.1:8080
kubectl --namespace default port-forward svc/jenkins 8080:8080

# --- Install pugin: SSH Build Agents
# --- get eth0 ip
ip a
10.0.0.168
# --- check default port
vi /etc/ssh/sshd_config
ssh 10.0.0.168 -p 2222
ssh-keygen
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519

# --- Install Plugin: Docker Pipeline