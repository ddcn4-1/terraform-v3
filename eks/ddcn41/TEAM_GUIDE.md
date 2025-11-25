#  배포 가이드 (Team Deployment Guide)

이 가이드는 각자의 독립된 환경(EKS 클러스터, RDS, Redis 등)을 구축하고, Helm을 사용하여 티켓팅 시스템 애플리케이션을 배포하는 방법을 설명합니다.

## 사전 준비 사항 (Prerequisites)

다음 도구들이 설치되어 있어야 합니다:
- [AWS CLI](https://docs.aws.amazon.com/ko_kr/cli/latest/userguide/getting-started-install.html) (본인 계정 자격 증명 설정 필요)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/ko/docs/tasks/tools/)
- [Helm](https://helm.sh/ko/docs/intro/install/)

---

## 1단계: 인프라 생성 (Terraform)

1.  **인프라 디렉토리로 이동**:
    ```bash
    cd eks/dh/infrastructure/environments/dev  # (또는 prod) 테라폼 코드가 있는 경로로 이동하세요
    ```

2.  **Terraform 초기화 및 적용**:
    ```bash
    terraform init
    terraform apply
    ```
    *프롬프트가 뜨면 `yes`를 입력하세요.*

3.  **중요: 출력값(Outputs) 기록하기**:
    Terraform 완료 후 출력되는 "Outputs" 값을 반드시 기록해 두세요. 다음 단계에서 필요합니다.
    *   `vpc_id`
    *   `public_subnets` (예: `subnet-xxxx,subnet-yyyy`)
    *   `rds_endpoint` (예: `ticketing-db.xxxx.ap-northeast-2.rds.amazonaws.com`)
    *   `redis_endpoint` (예: `ticketing-redis.xxxx.cache.amazonaws.com`)
    *   `ecr_repository_urls`

4.  **kubectl 설정**:
    새로 생성된 클러스터를 제어할 수 있도록 kubeconfig를 업데이트합니다:
    ```bash
    aws eks update-kubeconfig --region ap-northeast-2 --name <YOUR_CLUSTER_NAME>
    ```

---

## 2단계: Nginx Ingress Controller 설치 (필수)

CORS 문제 해결을 위해 Nginx Ingress를 사용합니다. 애플리케이션 배포 전에 먼저 설치해야 합니다.
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

## 3단계: 애플리케이션 배포 (Helm)

1.  **Helm 차트 디렉토리로 이동**:
    ```bash
    cd eks/dh/ticketing-chart
    ```

2.  **나만의 설정 파일 만들기**:
    기본 `values.yaml` 파일을 복사하여 `values-my-env.yaml`이라는 새 파일을 만듭니다.
    ```bash
    cp values.yaml values-my-env.yaml
    ```

3.  **`values-my-env.yaml` 수정하기**:
    `values-my-env.yaml` 파일을 열고, 1단계에서 기록해둔 **Outputs** 값으로 다음 항목들을 수정하세요.

    *   **이미지 저장소 (Image Repository)**:
        ```yaml
        image:
          repository: <본인의_ECR_레포지토리_URL_태그제외>
        ```
    *   **데이터베이스 & Redis**:
        ```yaml
        global:
          env:
            SPRING_DATASOURCE_URL: "jdbc:postgresql://<본인의_RDS_엔드포인트>:5432/ticketing"
            SPRING_REDIS_HOST: "<본인의_REDIS_엔드포인트>"
        ```
    *   **Ingress 서브넷**:
        ```yaml
        ingress:
          annotations:
            alb.ingress.kubernetes.io/subnets: <서브넷_ID_1>,<서브넷_ID_2>
        ```

4.  **Helm으로 배포하기**:
    수정한 설정 파일을 사용하여 설치 명령어를 실행합니다.
    ```bash
    helm install ticketing-release . -f values-my-env.yaml
    ```

5.  **배포 확인**:
    파드(Pod)가 정상적으로 실행 중인지 확인:
    ```bash
    kubectl get pods
    ```
    Ingress 주소 (로드밸런서 URL) 확인:
    ```bash
    kubectl get ingress
    # NAME                      CLASS   HOSTS   ADDRESS                                                                       PORTS   AGE
    # ticketing-nginx-ingress   nginx   *       aba80081518ea40e9aaa4df8535af698-760783890.ap-northeast-2.elb.amazonaws.com   80      2m55s
    ```

---

## 문제 해결 (Troubleshooting)

*   **데이터베이스 연결 실패**: `values-my-env.yaml` 파일의 `SPRING_DATASOURCE_URL`이 정확한지 확인하세요. 또한, EKS에서 RDS로 접근할 수 있도록 보안 그룹(Security Group)이 허용되어 있는지 확인해야 합니다.
*   **Ingress가 생성되지 않음**: `kubectl describe ingress ticketing-nginx-ingress` 명령어로 에러 메시지를 확인하세요. Nginx Ingress Controller가 정상적으로 설치되었는지 확인하세요.
