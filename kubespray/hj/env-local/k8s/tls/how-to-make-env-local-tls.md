# 로컬 인증서 설정

`kubectl create secret tls ddcn41-tls -n core --cert=local.ddcn41.com.pem --key=local.ddcn41.com-key.pem`

`kubectl create secret tls ddcn41-tls -n queue --cert=local.ddcn41.com.pem --key=local.ddcn41.com-key.pem`
