# Terraform v3 - Kubernetes MSA 배포

> 딥다이브 클라우드 네이티브 4회차 | 3차 프로젝트

2차 프로젝트의 MSA 애플리케이션을 Kubernetes 클러스터에 배포 프로젝트입니다.

**배포 환경**
- **EKS**: AWS 관리형 Kubernetes 서비스 (DH, HS)
- **Kubespray**: EC2 기반 자체 구축 Kubernetes 클러스터 (HJ, JY)

## 팀원 정보

| 이름 | 브랜치 | 기술 | 디렉토리 |
|------|--------|------|----------|
| DH | `eks-dh` | AWS EKS | `eks/dh/` |
| HS | `eks-hs` | AWS EKS | `eks/hs/` |
| HJ | `kbsp-hj` | Kubespray | `kubespray/hj/` |
| JY | `kbsp-jy` | Kubespray | `kubespray/jy/` |

## 프로젝트 구조

```
terraform-v3/
├── eks/                    # EKS 구현
│   ├── dh/                # DH 작업 공간
│   └── hs/                # HS 작업 공간
└── kubespray/             # Kubespray 구현
    ├── hj/                # HJ 작업 공간
    └── jy/                # JY 작업 공간
```

## 시작하기

### EKS 팀원 (DH, HS)

1. 본인 브랜치로 이동:
   ```bash
   git checkout eks-dh  # 또는 eks-hs
   ```

2. 작업 디렉토리로 이동:
   ```bash
   cd eks/dh  # 또는 eks/hs
   ```

3. AWS 자격증명 설정 후 구현 시작

### Kubespray 팀원 (HJ, JY)

1. 본인 브랜치로 이동:
   ```bash
   git checkout kbsp-hj  # 또는 kbsp-jy
   ```

2. 작업 디렉토리로 이동:
   ```bash
   cd kubespray/hj  # 또는 kubespray/jy
   ```

3. 인벤토리 준비 후 배포 시작

## 작업 방식

- 각자 본인 브랜치에서 독립적으로 작업
- 다른 팀원의 구현 내용 참고 가능
- main 브랜치는 초기 구조만 포함
- main으로의 병합은 나중에 결정

## 참고 자료

### 공통
- [Kubernetes 공식 문서](https://kubernetes.io/ko/docs/home/)
- [Terraform 공식 문서](https://developer.hashicorp.com/terraform/docs)
- [AWS 한국어 문서](https://docs.aws.amazon.com/ko_kr/)

### EKS 관련
- [AWS EKS 공식 문서](https://docs.aws.amazon.com/ko_kr/eks/)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform AWS VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [EKS Workshop](https://www.eksworkshop.com/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [eksctl 공식 문서](https://eksctl.io/)

### Kubespray 관련
- [Kubespray 공식 문서](https://kubespray.io/)
- [Kubespray GitHub](https://github.com/kubernetes-sigs/kubespray)
- [Ansible 공식 문서](https://docs.ansible.com/)
- [Kubespray 빠른 시작 가이드](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/getting-started.md)

### 유용한 도구
- [kubectl 치트시트](https://kubernetes.io/ko/docs/reference/kubectl/cheatsheet/)
- [k9s - Kubernetes CLI UI](https://k9scli.io/)
- [Lens - Kubernetes IDE](https://k8slens.dev/)
- [Terraform 치트시트](https://spacelift.io/blog/terraform-commands-cheat-sheet)
