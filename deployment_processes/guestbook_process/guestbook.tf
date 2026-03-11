locals {
  guestbook_namespace_template = "guestbook-#{if Octopus.Machine.Name}#{Octopus.Machine.Name | ToLower | Replace \" \" \"-\"}-#{/if}#{Octopus.Project.Id | ToLower | Replace \" \" \"-\"}-#{Octopus.Environment.Name | ToLower | Replace \" \" \"-\"}"

  guestbook_yaml = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.guestbook_namespace_template}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: yaml-guestbook-ui
  namespace: ${local.guestbook_namespace_template}
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: guestbook-ui
  template:
    metadata:
      labels:
        app: guestbook-ui
    spec:
      containers:
      - image: nginx
        name: guestbook-ui
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: yaml-guestbook-ui
  namespace: ${local.guestbook_namespace_template}
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: guestbook-ui
EOT
}