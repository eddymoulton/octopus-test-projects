locals {
  argo_yaml = <<-EOT
# This is an auto-generated file. DO NOT EDIT
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-application-controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: applicationset-controller
    app.kubernetes.io/name: argocd-applicationset-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-applicationset-controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/part-of: argocd
  name: argocd-dex-server
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: redis
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
  name: argocd-redis
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: repo-server
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
  name: argocd-repo-server
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-application-controller
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - appprojects
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - list
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: applicationset-controller
    app.kubernetes.io/name: argocd-applicationset-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-applicationset-controller
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - applicationsets
  - applicationsets/finalizers
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - argoproj.io
  resources:
  - appprojects
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - argoproj.io
  resources:
  - applicationsets/status
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - get
  - list
  - patch
  - watch
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  - extensions
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/part-of: argocd
  name: argocd-dex-server
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller
rules:
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - appprojects
  verbs:
  - get
  - list
  - watch
  - update
  - patch
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resourceNames:
  - argocd-notifications-cm
  resources:
  - configmaps
  verbs:
  - get
- apiGroups:
  - ""
  resourceNames:
  - argocd-notifications-secret
  resources:
  - secrets
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: redis
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
  name: argocd-redis
rules:
- apiGroups:
  - ""
  resourceNames:
  - argocd-redis
  resources:
  - secrets
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  - configmaps
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - patch
  - delete
- apiGroups:
  - argoproj.io
  resources:
  - applications
  - appprojects
  - applicationsets
  verbs:
  - create
  - get
  - list
  - watch
  - update
  - delete
  - patch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-application-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-application-controller
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: applicationset-controller
    app.kubernetes.io/name: argocd-applicationset-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-applicationset-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-applicationset-controller
subjects:
- kind: ServiceAccount
  name: argocd-applicationset-controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/part-of: argocd
  name: argocd-dex-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-dex-server
subjects:
- kind: ServiceAccount
  name: argocd-dex-server
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-notifications-controller
subjects:
- kind: ServiceAccount
  name: argocd-notifications-controller
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: redis
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
  name: argocd-redis
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-redis
subjects:
- kind: ServiceAccount
  name: argocd-redis
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: argocd-server
subjects:
- kind: ServiceAccount
  name: argocd-server
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-gpg-keys-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-gpg-keys-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-rbac-cm
---
apiVersion: v1
data:
  ssh_known_hosts: |
    # This file was automatically generated by hack/update-ssh-known-hosts.sh. DO NOT EDIT
    [ssh.github.com]:443 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    [ssh.github.com]:443 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    [ssh.github.com]:443 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
    bitbucket.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPIQmuzMBuKdWeF4+a2sjSSpBK0iqitSQ+5BM9KhpexuGt20JpTVM7u5BDZngncgrqDMbWdxMWWOGtZ9UgbqgZE=
    bitbucket.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO
    bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQeJzhupRu0u0cdegZIa8e86EG2qOCsIsD1Xw0xSeiPDlCr7kq97NLmMbpKTX6Esc30NuoqEEHCuc7yWtwp8dI76EEEB1VqY9QJq6vk+aySyboD5QF61I/1WeTwu+deCbgKMGbUijeXhtfbxSxm6JwGrXrhBdofTsbKRUsrN1WoNgUa8uqN1Vx6WAJw1JHPhglEGGHea6QICwJOAr/6mrui/oB7pkaWKHj3z7d1IC4KWLtY47elvjbaTlkN04Kc/5LFEirorGYVbt15kAUlqGM65pk6ZBxtaO3+30LVlORZkxOh+LKL/BvbZ/iRNhItLqNyieoQj/uh/7Iv4uyH/cV/0b4WDSd3DptigWq84lJubb9t/DnZlrJazxyDCulTmKdOR7vs9gMTo+uoIrPSb8ScTtvw65+odKAlBj59dhnVp9zd7QUojOpXlL62Aw56U4oO+FALuevvMjiWeavKhJqlR7i5n9srYcrNV7ttmDw7kf/97P5zauIhxcjX+xHv4M=
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
    gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
    gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
    gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyokEi/ueaBMCvbcTHhO7FcwzY92WK4Yt0aGROY5qX2UKSeOvuP4D6TPqKF1onrSzH9bx9XUf2lEdWT/ia1NEKjunUqu1xOB/StKDHMoX4/OKyIzuS0q/T1zOATthvasJFoPrAjkohTyaDUz2LN5JoH839hViyEG82yB+MjcFV5MU3N1l1QL3cVUCh93xSaua1N85qivl+siMkPGbO5xR/En4iEY6K2XPASUEMaieWVNTRCtJ4S8H+9
    ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
    vs-ssh.visualstudio.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTWqNqOlzGJOfGJ4NakVyIzf1rXYd4d7wo6jBlkLvCA4odBlL0mDUyZ0/QUfTTqeu+tm22gOsv+VrVTMk6vwRU75gY/y9ut5Mb3bR5BV58dKXyq9A9UeB5Cakehn5Zgm6x1mKoVyf+FFn26iYqXJRgzIZZcZ5V6hrE0Qg39kZm4az48o0AUbf6Sp4SLdvnuMa2sVNwHBboS7EJkm57XQPVU3/QpyNLHbWDdzwtrlS+ez30S3AdYhLKEOxAG8weOnyrtLJAUen9mTkol8oII1edf7mWWbWVf0nBmly21+nZcmCTISQBtdcyPaEno7fFQMDD26/s0lfKob4Kw8H
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-ssh-known-hosts-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-ssh-known-hosts-cm
---
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/name: argocd-tls-certs-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-tls-certs-cm
---
apiVersion: v1
kind: Secret
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-secret
type: Opaque
---
apiVersion: v1
kind: Secret
metadata:
  labels:
    app.kubernetes.io/name: argocd-secret
    app.kubernetes.io/part-of: argocd
  name: argocd-secret
type: Opaque
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: applicationset-controller
    app.kubernetes.io/name: argocd-applicationset-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-applicationset-controller
spec:
  ports:
  - name: webhook
    port: 7000
    protocol: TCP
    targetPort: webhook
  - name: metrics
    port: 8080
    protocol: TCP
    targetPort: metrics
  selector:
    app.kubernetes.io/name: argocd-applicationset-controller
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/part-of: argocd
  name: argocd-dex-server
spec:
  ports:
  - appProtocol: TCP
    name: http
    port: 5556
    protocol: TCP
    targetPort: 5556
  - name: grpc
    port: 5557
    protocol: TCP
    targetPort: 5557
  - name: metrics
    port: 5558
    protocol: TCP
    targetPort: 5558
  selector:
    app.kubernetes.io/name: argocd-dex-server
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: metrics
    app.kubernetes.io/name: argocd-metrics
    app.kubernetes.io/part-of: argocd
  name: argocd-metrics
spec:
  ports:
  - name: metrics
    port: 8082
    protocol: TCP
    targetPort: 8082
  selector:
    app.kubernetes.io/name: argocd-application-controller
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller-metrics
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller-metrics
spec:
  ports:
  - name: metrics
    port: 9001
    protocol: TCP
    targetPort: 9001
  selector:
    app.kubernetes.io/name: argocd-notifications-controller
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: redis
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
  name: argocd-redis
spec:
  ports:
  - name: tcp-redis
    port: 6379
    targetPort: 6379
  selector:
    app.kubernetes.io/name: argocd-redis
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: repo-server
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
  name: argocd-repo-server
spec:
  ports:
  - name: server
    port: 8081
    protocol: TCP
    targetPort: 8081
  - name: metrics
    port: 8084
    protocol: TCP
    targetPort: 8084
  selector:
    app.kubernetes.io/name: argocd-repo-server
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server-metrics
    app.kubernetes.io/part-of: argocd
  name: argocd-server-metrics
spec:
  ports:
  - name: metrics
    port: 8083
    protocol: TCP
    targetPort: 8083
  selector:
    app.kubernetes.io/name: argocd-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: applicationset-controller
    app.kubernetes.io/name: argocd-applicationset-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-applicationset-controller
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-applicationset-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-applicationset-controller
    spec:
      containers:
      - args:
        - /usr/local/bin/argocd-applicationset-controller
        env:
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_GLOBAL_PRESERVED_ANNOTATIONS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.global.preserved.annotations
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_GLOBAL_PRESERVED_LABELS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.global.preserved.labels
              name: argocd-cmd-params-cm
              optional: true
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_LEADER_ELECTION
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.leader.election
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_REPO_SERVER
          valueFrom:
            configMapKeyRef:
              key: repo.server
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_POLICY
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.policy
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_POLICY_OVERRIDE
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.policy.override
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_DEBUG
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.debug
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_LOGLEVEL
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_DRY_RUN
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.dryrun
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_GIT_MODULES_ENABLED
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.git.submodule
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_PROGRESSIVE_SYNCS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.progressive.syncs
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_TOKENREF_STRICT_MODE
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.tokenref.strict.mode
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_NEW_GIT_FILE_GLOBBING
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.new.git.file.globbing
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_REPO_SERVER_PLAINTEXT
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.repo.server.plaintext
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_REPO_SERVER_STRICT_TLS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.repo.server.strict.tls
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.repo.server.timeout.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_CONCURRENT_RECONCILIATIONS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.concurrent.reconciliations.max
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_NAMESPACES
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.namespaces
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_SCM_ROOT_CA_PATH
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.scm.root.ca.path
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ALLOWED_SCM_PROVIDERS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.allowed.scm.providers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_SCM_PROVIDERS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.scm.providers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_WEBHOOK_PARALLELISM_LIMIT
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.webhook.parallelism.limit
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_REQUEUE_AFTER
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.requeue.after
              name: argocd-cmd-params-cm
              optional: true
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        name: argocd-applicationset-controller
        ports:
        - containerPort: 7000
          name: webhook
        - containerPort: 8080
          name: metrics
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /app/config/ssh
          name: ssh-known-hosts
        - mountPath: /app/config/tls
          name: tls-certs
        - mountPath: /app/config/gpg/source
          name: gpg-keys
        - mountPath: /app/config/gpg/keys
          name: gpg-keyring
        - mountPath: /tmp
          name: tmp
        - mountPath: /app/config/reposerver/tls
          name: argocd-repo-server-tls
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: argocd-applicationset-controller
      volumes:
      - configMap:
          name: argocd-ssh-known-hosts-cm
        name: ssh-known-hosts
      - configMap:
          name: argocd-tls-certs-cm
        name: tls-certs
      - configMap:
          name: argocd-gpg-keys-cm
        name: gpg-keys
      - emptyDir: {}
        name: gpg-keyring
      - emptyDir: {}
        name: tmp
      - name: argocd-repo-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-repo-server-tls
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/part-of: argocd
  name: argocd-dex-server
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-dex-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-dex-server
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/part-of: argocd
              topologyKey: kubernetes.io/hostname
            weight: 5
      containers:
      - command:
        - /shared/argocd-dex
        - rundex
        env:
        - name: ARGOCD_DEX_SERVER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: dexserver.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_DEX_SERVER_LOGLEVEL
          valueFrom:
            configMapKeyRef:
              key: dexserver.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_DEX_SERVER_DISABLE_TLS
          valueFrom:
            configMapKeyRef:
              key: dexserver.disable.tls
              name: argocd-cmd-params-cm
              optional: true
        image: ghcr.io/dexidp/dex:v2.41.1
        imagePullPolicy: Always
        name: dex
        ports:
        - containerPort: 5556
        - containerPort: 5557
        - containerPort: 5558
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /shared
          name: static-files
        - mountPath: /tmp
          name: dexconfig
        - mountPath: /tls
          name: argocd-dex-server-tls
      initContainers:
      - command:
        - /bin/cp
        - -n
        - /usr/local/bin/argocd
        - /shared/argocd-dex
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        name: copyutil
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /shared
          name: static-files
        - mountPath: /tmp
          name: dexconfig
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: argocd-dex-server
      volumes:
      - emptyDir: {}
        name: static-files
      - emptyDir: {}
        name: dexconfig
      - name: argocd-dex-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-dex-server-tls
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-notifications-controller
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-notifications-controller
    spec:
      containers:
      - args:
        - /usr/local/bin/argocd-notifications
        env:
        - name: ARGOCD_NOTIFICATIONS_CONTROLLER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: notificationscontroller.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_NOTIFICATIONS_CONTROLLER_LOGLEVEL
          valueFrom:
            configMapKeyRef:
              key: notificationscontroller.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_NAMESPACES
          valueFrom:
            configMapKeyRef:
              key: application.namespaces
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_NOTIFICATION_CONTROLLER_SELF_SERVICE_NOTIFICATION_ENABLED
          valueFrom:
            configMapKeyRef:
              key: notificationscontroller.selfservice.enabled
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_NOTIFICATION_CONTROLLER_REPO_SERVER_PLAINTEXT
          valueFrom:
            configMapKeyRef:
              key: notificationscontroller.repo.server.plaintext
              name: argocd-cmd-params-cm
              optional: true
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        livenessProbe:
          tcpSocket:
            port: 9001
        name: argocd-notifications-controller
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
        volumeMounts:
        - mountPath: /app/config/tls
          name: tls-certs
        - mountPath: /app/config/reposerver/tls
          name: argocd-repo-server-tls
        workingDir: /app
      nodeSelector:
        kubernetes.io/os: linux
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      serviceAccountName: argocd-notifications-controller
      volumes:
      - configMap:
          name: argocd-tls-certs-cm
        name: tls-certs
      - name: argocd-repo-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-repo-server-tls
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: redis
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/part-of: argocd
  name: argocd-redis
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-redis
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-redis
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: argocd-redis
              topologyKey: kubernetes.io/hostname
            weight: 100
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/part-of: argocd
              topologyKey: kubernetes.io/hostname
            weight: 5
      containers:
      - args:
        - --save
        - ""
        - --appendonly
        - "no"
        - --requirepass $(REDIS_PASSWORD)
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              key: auth
              name: argocd-redis
        image: redis:7.0.15-alpine
        imagePullPolicy: Always
        name: redis
        ports:
        - containerPort: 6379
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
      initContainers:
      - command:
        - argocd
        - admin
        - redis-initial-password
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: IfNotPresent
        name: secret-init
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
      nodeSelector:
        kubernetes.io/os: linux
      securityContext:
        runAsNonRoot: true
        runAsUser: 999
        seccompProfile:
          type: RuntimeDefault
      serviceAccountName: argocd-redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: repo-server
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
  name: argocd-repo-server
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-repo-server
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: argocd-repo-server
              topologyKey: kubernetes.io/hostname
            weight: 100
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/part-of: argocd
              topologyKey: kubernetes.io/hostname
            weight: 5
      automountServiceAccountToken: false
      containers:
      - args:
        - /usr/local/bin/argocd-repo-server
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              key: auth
              name: argocd-redis
        - name: ARGOCD_RECONCILIATION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: timeout.reconciliation
              name: argocd-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: reposerver.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_LOGLEVEL
          valueFrom:
            configMapKeyRef:
              key: reposerver.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_PARALLELISM_LIMIT
          valueFrom:
            configMapKeyRef:
              key: reposerver.parallelism.limit
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_LISTEN_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: reposerver.listen.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_LISTEN_METRICS_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: reposerver.metrics.listen.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_DISABLE_TLS
          valueFrom:
            configMapKeyRef:
              key: reposerver.disable.tls
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_MIN_VERSION
          valueFrom:
            configMapKeyRef:
              key: reposerver.tls.minversion
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_MAX_VERSION
          valueFrom:
            configMapKeyRef:
              key: reposerver.tls.maxversion
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_CIPHERS
          valueFrom:
            configMapKeyRef:
              key: reposerver.tls.ciphers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: reposerver.repo.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_SERVER
          valueFrom:
            configMapKeyRef:
              key: redis.server
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_COMPRESSION
          valueFrom:
            configMapKeyRef:
              key: redis.compression
              name: argocd-cmd-params-cm
              optional: true
        - name: REDISDB
          valueFrom:
            configMapKeyRef:
              key: redis.db
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_DEFAULT_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: reposerver.default.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_OTLP_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: otlp.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_OTLP_INSECURE
          valueFrom:
            configMapKeyRef:
              key: otlp.insecure
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_OTLP_HEADERS
          valueFrom:
            configMapKeyRef:
              key: otlp.headers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_MAX_COMBINED_DIRECTORY_MANIFESTS_SIZE
          valueFrom:
            configMapKeyRef:
              key: reposerver.max.combined.directory.manifests.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_PLUGIN_TAR_EXCLUSIONS
          valueFrom:
            configMapKeyRef:
              key: reposerver.plugin.tar.exclusions
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_PLUGIN_USE_MANIFEST_GENERATE_PATHS
          valueFrom:
            configMapKeyRef:
              key: reposerver.plugin.use.manifest.generate.paths
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_ALLOW_OUT_OF_BOUNDS_SYMLINKS
          valueFrom:
            configMapKeyRef:
              key: reposerver.allow.oob.symlinks
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_STREAMED_MANIFEST_MAX_TAR_SIZE
          valueFrom:
            configMapKeyRef:
              key: reposerver.streamed.manifest.max.tar.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_STREAMED_MANIFEST_MAX_EXTRACTED_SIZE
          valueFrom:
            configMapKeyRef:
              key: reposerver.streamed.manifest.max.extracted.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_HELM_MANIFEST_MAX_EXTRACTED_SIZE
          valueFrom:
            configMapKeyRef:
              key: reposerver.helm.manifest.max.extracted.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_DISABLE_HELM_MANIFEST_MAX_EXTRACTED_SIZE
          valueFrom:
            configMapKeyRef:
              key: reposerver.disable.helm.manifest.max.extracted.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REVISION_CACHE_LOCK_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: reposerver.revision.cache.lock.timeout
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_GIT_MODULES_ENABLED
          valueFrom:
            configMapKeyRef:
              key: reposerver.enable.git.submodule
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_GIT_LS_REMOTE_PARALLELISM_LIMIT
          valueFrom:
            configMapKeyRef:
              key: reposerver.git.lsremote.parallelism.limit
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_GIT_REQUEST_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: reposerver.git.request.timeout
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_GRPC_MAX_SIZE_MB
          valueFrom:
            configMapKeyRef:
              key: reposerver.grpc.max.size
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_REPO_SERVER_INCLUDE_HIDDEN_DIRECTORIES
          valueFrom:
            configMapKeyRef:
              key: reposerver.include.hidden.directories
              name: argocd-cmd-params-cm
              optional: true
        - name: HELM_CACHE_HOME
          value: /helm-working-dir
        - name: HELM_CONFIG_HOME
          value: /helm-working-dir
        - name: HELM_DATA_HOME
          value: /helm-working-dir
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /healthz?full=true
            port: 8084
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
        name: argocd-repo-server
        ports:
        - containerPort: 8081
        - containerPort: 8084
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8084
          initialDelaySeconds: 5
          periodSeconds: 10
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /app/config/ssh
          name: ssh-known-hosts
        - mountPath: /app/config/tls
          name: tls-certs
        - mountPath: /app/config/gpg/source
          name: gpg-keys
        - mountPath: /app/config/gpg/keys
          name: gpg-keyring
        - mountPath: /app/config/reposerver/tls
          name: argocd-repo-server-tls
        - mountPath: /tmp
          name: tmp
        - mountPath: /helm-working-dir
          name: helm-working-dir
        - mountPath: /home/argocd/cmp-server/plugins
          name: plugins
      initContainers:
      - command:
        - /bin/cp
        - -n
        - /usr/local/bin/argocd
        - /var/run/argocd/argocd-cmp-server
        image: quay.io/argoproj/argocd:latest
        name: copyutil
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /var/run/argocd
          name: var-files
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: argocd-repo-server
      volumes:
      - configMap:
          name: argocd-ssh-known-hosts-cm
        name: ssh-known-hosts
      - configMap:
          name: argocd-tls-certs-cm
        name: tls-certs
      - configMap:
          name: argocd-gpg-keys-cm
        name: gpg-keys
      - emptyDir: {}
        name: gpg-keyring
      - emptyDir: {}
        name: tmp
      - emptyDir: {}
        name: helm-working-dir
      - name: argocd-repo-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-repo-server-tls
      - emptyDir: {}
        name: var-files
      - emptyDir: {}
        name: plugins
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-server
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: argocd-server
              topologyKey: kubernetes.io/hostname
            weight: 100
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/part-of: argocd
              topologyKey: kubernetes.io/hostname
            weight: 5
      containers:
      - args:
        - /usr/local/bin/argocd-server
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              key: auth
              name: argocd-redis
        - name: ARGOCD_SERVER_INSECURE
          valueFrom:
            configMapKeyRef:
              key: server.insecure
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_BASEHREF
          valueFrom:
            configMapKeyRef:
              key: server.basehref
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_ROOTPATH
          valueFrom:
            configMapKeyRef:
              key: server.rootpath
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: server.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              key: server.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_REPO_SERVER
          valueFrom:
            configMapKeyRef:
              key: repo.server
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_DEX_SERVER
          valueFrom:
            configMapKeyRef:
              key: server.dex.server
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_DISABLE_AUTH
          valueFrom:
            configMapKeyRef:
              key: server.disable.auth
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_ENABLE_GZIP
          valueFrom:
            configMapKeyRef:
              key: server.enable.gzip
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS
          valueFrom:
            configMapKeyRef:
              key: server.repo.server.timeout.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_X_FRAME_OPTIONS
          valueFrom:
            configMapKeyRef:
              key: server.x.frame.options
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_CONTENT_SECURITY_POLICY
          valueFrom:
            configMapKeyRef:
              key: server.content.security.policy
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_REPO_SERVER_PLAINTEXT
          valueFrom:
            configMapKeyRef:
              key: server.repo.server.plaintext
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_REPO_SERVER_STRICT_TLS
          valueFrom:
            configMapKeyRef:
              key: server.repo.server.strict.tls
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_DEX_SERVER_PLAINTEXT
          valueFrom:
            configMapKeyRef:
              key: server.dex.server.plaintext
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_DEX_SERVER_STRICT_TLS
          valueFrom:
            configMapKeyRef:
              key: server.dex.server.strict.tls
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_MIN_VERSION
          valueFrom:
            configMapKeyRef:
              key: server.tls.minversion
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_MAX_VERSION
          valueFrom:
            configMapKeyRef:
              key: server.tls.maxversion
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_TLS_CIPHERS
          valueFrom:
            configMapKeyRef:
              key: server.tls.ciphers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_CONNECTION_STATUS_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: server.connection.status.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_OIDC_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: server.oidc.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_LOGIN_ATTEMPTS_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: server.login.attempts.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_STATIC_ASSETS
          valueFrom:
            configMapKeyRef:
              key: server.staticassets
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APP_STATE_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: server.app.state.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_SERVER
          valueFrom:
            configMapKeyRef:
              key: redis.server
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_COMPRESSION
          valueFrom:
            configMapKeyRef:
              key: redis.compression
              name: argocd-cmd-params-cm
              optional: true
        - name: REDISDB
          valueFrom:
            configMapKeyRef:
              key: redis.db
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_DEFAULT_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: server.default.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_MAX_COOKIE_NUMBER
          valueFrom:
            configMapKeyRef:
              key: server.http.cookie.maxnumber
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_LISTEN_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: server.listen.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_METRICS_LISTEN_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: server.metrics.listen.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_OTLP_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: otlp.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_OTLP_INSECURE
          valueFrom:
            configMapKeyRef:
              key: otlp.insecure
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_OTLP_HEADERS
          valueFrom:
            configMapKeyRef:
              key: otlp.headers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_NAMESPACES
          valueFrom:
            configMapKeyRef:
              key: application.namespaces
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_ENABLE_PROXY_EXTENSION
          valueFrom:
            configMapKeyRef:
              key: server.enable.proxy.extension
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_K8SCLIENT_RETRY_MAX
          valueFrom:
            configMapKeyRef:
              key: server.k8sclient.retry.max
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_K8SCLIENT_RETRY_BASE_BACKOFF
          valueFrom:
            configMapKeyRef:
              key: server.k8sclient.retry.base.backoff
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_API_CONTENT_TYPES
          valueFrom:
            configMapKeyRef:
              key: server.api.content.types
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_SERVER_WEBHOOK_PARALLELISM_LIMIT
          valueFrom:
            configMapKeyRef:
              key: server.webhook.parallelism.limit
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_NEW_GIT_FILE_GLOBBING
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.new.git.file.globbing
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_SCM_ROOT_CA_PATH
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.scm.root.ca.path
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ALLOWED_SCM_PROVIDERS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.allowed.scm.providers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATIONSET_CONTROLLER_ENABLE_SCM_PROVIDERS
          valueFrom:
            configMapKeyRef:
              key: applicationsetcontroller.enable.scm.providers
              name: argocd-cmd-params-cm
              optional: true
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        livenessProbe:
          httpGet:
            path: /healthz?full=true
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 30
          timeoutSeconds: 5
        name: argocd-server
        ports:
        - containerPort: 8080
        - containerPort: 8083
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 30
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /app/config/ssh
          name: ssh-known-hosts
        - mountPath: /app/config/tls
          name: tls-certs
        - mountPath: /app/config/server/tls
          name: argocd-repo-server-tls
        - mountPath: /app/config/dex/tls
          name: argocd-dex-server-tls
        - mountPath: /home/argocd
          name: plugins-home
        - mountPath: /tmp
          name: tmp
        - mountPath: /home/argocd/params
          name: argocd-cmd-params-cm
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: argocd-server
      volumes:
      - emptyDir: {}
        name: plugins-home
      - emptyDir: {}
        name: tmp
      - configMap:
          name: argocd-ssh-known-hosts-cm
        name: ssh-known-hosts
      - configMap:
          name: argocd-tls-certs-cm
        name: tls-certs
      - name: argocd-repo-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-repo-server-tls
      - name: argocd-dex-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-dex-server-tls
      - configMap:
          items:
          - key: server.profile.enabled
            path: profiler.enabled
          name: argocd-cmd-params-cm
          optional: true
        name: argocd-cmd-params-cm
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  labels:
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-application-controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  serviceName: argocd-application-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-application-controller
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: argocd-application-controller
              topologyKey: kubernetes.io/hostname
            weight: 100
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/part-of: argocd
              topologyKey: kubernetes.io/hostname
            weight: 5
      containers:
      - args:
        - /usr/local/bin/argocd-application-controller
        env:
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              key: auth
              name: argocd-redis
        - name: ARGOCD_CONTROLLER_REPLICAS
          value: "1"
        - name: ARGOCD_RECONCILIATION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: timeout.reconciliation
              name: argocd-cm
              optional: true
        - name: ARGOCD_HARD_RECONCILIATION_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: timeout.hard.reconciliation
              name: argocd-cm
              optional: true
        - name: ARGOCD_RECONCILIATION_JITTER
          valueFrom:
            configMapKeyRef:
              key: timeout.reconciliation.jitter
              name: argocd-cm
              optional: true
        - name: ARGOCD_REPO_ERROR_GRACE_PERIOD_SECONDS
          valueFrom:
            configMapKeyRef:
              key: controller.repo.error.grace.period.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER
          valueFrom:
            configMapKeyRef:
              key: repo.server
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS
          valueFrom:
            configMapKeyRef:
              key: controller.repo.server.timeout.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_STATUS_PROCESSORS
          valueFrom:
            configMapKeyRef:
              key: controller.status.processors
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_OPERATION_PROCESSORS
          valueFrom:
            configMapKeyRef:
              key: controller.operation.processors
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_LOGFORMAT
          valueFrom:
            configMapKeyRef:
              key: controller.log.format
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_LOGLEVEL
          valueFrom:
            configMapKeyRef:
              key: controller.log.level
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_METRICS_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: controller.metrics.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_SELF_HEAL_TIMEOUT_SECONDS
          valueFrom:
            configMapKeyRef:
              key: controller.self.heal.timeout.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_SELF_HEAL_BACKOFF_TIMEOUT_SECONDS
          valueFrom:
            configMapKeyRef:
              key: controller.self.heal.backoff.timeout.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_SELF_HEAL_BACKOFF_FACTOR
          valueFrom:
            configMapKeyRef:
              key: controller.self.heal.backoff.factor
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_SELF_HEAL_BACKOFF_CAP_SECONDS
          valueFrom:
            configMapKeyRef:
              key: controller.self.heal.backoff.cap.seconds
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_PLAINTEXT
          valueFrom:
            configMapKeyRef:
              key: controller.repo.server.plaintext
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_STRICT_TLS
          valueFrom:
            configMapKeyRef:
              key: controller.repo.server.strict.tls
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_PERSIST_RESOURCE_HEALTH
          valueFrom:
            configMapKeyRef:
              key: controller.resource.health.persist
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APP_STATE_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: controller.app.state.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_SERVER
          valueFrom:
            configMapKeyRef:
              key: redis.server
              name: argocd-cmd-params-cm
              optional: true
        - name: REDIS_COMPRESSION
          valueFrom:
            configMapKeyRef:
              key: redis.compression
              name: argocd-cmd-params-cm
              optional: true
        - name: REDISDB
          valueFrom:
            configMapKeyRef:
              key: redis.db
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_DEFAULT_CACHE_EXPIRATION
          valueFrom:
            configMapKeyRef:
              key: controller.default.cache.expiration
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_OTLP_ADDRESS
          valueFrom:
            configMapKeyRef:
              key: otlp.address
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_OTLP_INSECURE
          valueFrom:
            configMapKeyRef:
              key: otlp.insecure
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_OTLP_HEADERS
          valueFrom:
            configMapKeyRef:
              key: otlp.headers
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_NAMESPACES
          valueFrom:
            configMapKeyRef:
              key: application.namespaces
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_CONTROLLER_SHARDING_ALGORITHM
          valueFrom:
            configMapKeyRef:
              key: controller.sharding.algorithm
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT
          valueFrom:
            configMapKeyRef:
              key: controller.kubectl.parallelism.limit
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_K8SCLIENT_RETRY_MAX
          valueFrom:
            configMapKeyRef:
              key: controller.k8sclient.retry.max
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_K8SCLIENT_RETRY_BASE_BACKOFF
          valueFrom:
            configMapKeyRef:
              key: controller.k8sclient.retry.base.backoff
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_APPLICATION_CONTROLLER_SERVER_SIDE_DIFF
          valueFrom:
            configMapKeyRef:
              key: controller.diff.server.side
              name: argocd-cmd-params-cm
              optional: true
        - name: ARGOCD_IGNORE_NORMALIZER_JQ_TIMEOUT
          valueFrom:
            configMapKeyRef:
              key: controller.ignore.normalizer.jq.timeout
              name: argocd-cmd-params-cm
              optional: true
        image: quay.io/argoproj/argocd:latest
        imagePullPolicy: Always
        name: argocd-application-controller
        ports:
        - containerPort: 8082
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8082
          initialDelaySeconds: 5
          periodSeconds: 10
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /app/config/controller/tls
          name: argocd-repo-server-tls
        - mountPath: /home/argocd
          name: argocd-home
        - mountPath: /home/argocd/params
          name: argocd-cmd-params-cm
        workingDir: /home/argocd
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: argocd-application-controller
      volumes:
      - emptyDir: {}
        name: argocd-home
      - name: argocd-repo-server-tls
        secret:
          items:
          - key: tls.crt
            path: tls.crt
          - key: tls.key
            path: tls.key
          - key: ca.crt
            path: ca.crt
          optional: true
          secretName: argocd-repo-server-tls
      - configMap:
          items:
          - key: controller.profile.enabled
            path: profiler.enabled
          name: argocd-cmd-params-cm
          optional: true
        name: argocd-cmd-params-cm
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-application-controller-network-policy
spec:
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - port: 8082
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-applicationset-controller-network-policy
spec:
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - port: 7000
      protocol: TCP
    - port: 8080
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-applicationset-controller
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-dex-server-network-policy
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-server
    ports:
    - port: 5556
      protocol: TCP
    - port: 5557
      protocol: TCP
  - from:
    - namespaceSelector: {}
    ports:
    - port: 5558
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-dex-server
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  labels:
    app.kubernetes.io/component: notifications-controller
    app.kubernetes.io/name: argocd-notifications-controller
    app.kubernetes.io/part-of: argocd
  name: argocd-notifications-controller-network-policy
spec:
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - port: 9001
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-notifications-controller
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-redis-network-policy
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-server
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-repo-server
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-application-controller
    ports:
    - port: 6379
      protocol: TCP
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-redis
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-repo-server-network-policy
spec:
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-server
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-application-controller
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-notifications-controller
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: argocd-applicationset-controller
    ports:
    - port: 8081
      protocol: TCP
  - from:
    - namespaceSelector: {}
    ports:
    - port: 8084
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server-network-policy
spec:
  ingress:
  - {}
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
  - Ingress
EOT
}