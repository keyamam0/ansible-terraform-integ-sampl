# ansible-terraform-integ-sampl

## List
|  ファイル／フォルダ  |    | 説明 |
| ---- | ---- | --- |
|  iac_aws.yml  |  Ansible Playbook  | このPlaybookでIaC全体を統合的に実行 |
|  inventory-source_aws_ec2.yml  | Ansible Inventory Sorce  | Terraformで作成したEC2の情報を動的に吸い出すダイナミックインベントリのコード |
|  terraform  |  Terraform Script  | Terraform Scriptは、上記のPlaybookから起動。単独で動かす場合は、terraform init->apply |
|  ee-build  |  EEのビルド素材  | Ansible Towerで実行する時に必要。Terraform入りのEEコンテナをビルドするためのファイル、ベースコンテナにRHELを使っているので、ビルド環境にRHELサブスクが必要です |


## Ansibleコマンドで実行

### オペレーション
```
ansible-playbook -i inventory-source_aws_ec2.yml iac_aws.yml --private-key="../my-keypair-tmp.pem" --ssh-extra-args="-o 'StrictHostKeyChecking=no'"
```

## Ansible Controller(GUI、旧Ansible Tower)

### 前提条件
Terraform入りのAnsible EEコンテナをビルドして、quey.ioなどのコンテナリポジトリに置いておく

```
sudo python3.9 -m pip install ansible-builder
```

```
ansible-builder build
```

```
podman lgin quey.io
```

```
podman push quay.io/keyamamo/ee-terraform:latest 
```

```
podman tag localhost/ansible-execution-env quay.io/xxx/ee-terraform
```


