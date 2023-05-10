# Ansible&Terraform インテグレーションSample
このサンプルでは、AnsibleからTerraformスクリプトとAnsibleプレイブックを統合して実行する方法を示しています

この方法で、例えば、クラウドリソースを作成するためのTerraformの処理と、サーバーへのモジュールのインストールや設定をするAnsible処理を**一連の流れ**として組み合わせて実行できます

具体的な処理内容としては、TerraformでAWS EC2を作成し、AnsibleでHTTPDのインストールと起動するものとなっています

なお、**Ansibleコマンドから実行する方法**と、**Ansible Controller（旧Ansible Tower）から実行する方法**の２つの方法を後述しています

## 統合メリット（所感）

- TerraformとAnsibleの得意な部分を、シームレスに組み合わせて活用できる

- AnsibleのサブモジュールとしてTerraformを管理することにより、管理性が増す？

- PlaybookとHCL、両方覚える必要はありますが、得意な部分を組み合わせるので、コードをシンプルに保てて、テンプレエンジン使うみたいなごちゃごちゃしてくる（イメージ）を回避できる

- (もうちょっと、実用的なユースケースまで、落としたいところ)

## 要改善memo
- 現状、tfstateファイルをローカルに置いていて、Ansible ControllerからEEコンテナで動かす場合には消えちゃう問題あり。S3とかにリモート保存するように修正しなくちゃなぁ（差分ApplyやDestroyが効かないのは大きな問題だ）

- Webhook使ったGitOps化などはユースケースあるかなぁ、、

- TerraformをAnsibleから叩くCollectionモジュールは、Community版を使っています。商用版モジュールにも移行してみたい

## ファイル一覧
|  ファイル／フォルダ  |    | 説明 |
| ---- | ---- | --- |
|  iac_aws.yml  |  Ansible Playbook  | 【Ansibleコマンドから実行時に使用】このPlaybookでTerraform処理〜Inventory更新〜Ansible処理までIaC全体を一括実行 |
|  inventory-source_aws_ec2.yml  | Ansible Inventory Sorce  | 【Ansibleコマンドから実行時に使用】Terraformで作成したEC2の情報を動的に吸い出すダイナミックインベントリのコード(Ansible Controllerから実行時は、GUIによる設定を使う) |
|  iac_aws-p1.yml  |  Ansible Playbook  | 【Ansible Controllerから実行時に使用】このPlaybookでTerraform処理を実施する **※Ansible Controllerから実行時は、コードでInventory更新が出来ないので、2Partに分けて、ワークフローテンプレートでp1とp2を一連の処理に統合** |
|  iac_aws-p2.yml  |  Ansible Playbook  | 【Ansible Controllerから実行時に使用】このPlaybookでTerraform処理で作成したEC2への設定を行う、Inventoryはタスク起動時に更新されるように設定しておくこと |
|  terraform  |  Terraform Script  | Terraform Scriptは、上記のAnsibleから起動。単独で動かす場合は、terraform init->applyで実施 |
|  ee-build  |  EEコンテナのビルド素材  | Ansible Towerで実行する時に必要。Terraform入りのEEコンテナをビルドするためのファイル、ベースコンテナにRHELを使っているので、ビルド環境にRHELサブスクが必要です |


## Ansibleコマンドから実行する場合

事前にAWSプロファイルの作成、EC2のSSH keypair(下のコマンドでは../my-keypair-tmp.pemで設定)を用意しておく
```bash
ansible-playbook -i inventory-source_aws_ec2.yml iac_aws.yml --private-key="../my-keypair-tmp.pem" --ssh-extra-args="-o 'StrictHostKeyChecking=no'"
```

## Ansible Controller(GUI、旧Ansible Tower)から実行する場合


### 1.事前準備① EEのビルドと設定
Terraform、Unzip、必要なCollectionなどデフォルトで入っていないモジュール入りのAnsible EEコンテナをビルドして、quey.ioなどのコンテナリポジトリに置いておく

@作業端末、EEコンテナのビルドツールをインストール
```bash
sudo python3.9 -m pip install ansible-builder
```
@作業端末、ee-buildディレクトリでコンテナBuild
```bash
ansible-builder build
```

@作業端末、出来たコンテナイメージをレジストリ登録（RHELで作業してるのでPodman）
```bash
podman login quay.io
podman tag localhost/ansible-execution-env quay.io/xxx/ee-terraform
podman push quay.io/xxx/ee-terraform:latest 
```

@Ansible Controller、管理-実行環境(EE)から新規のEEを追加
- 名前: 任意(ここでは**ee-terraform**と仮に設定)
- イメージ: レジストリのPath

iac_aws_p1.ymlを実行するTemplateの実行環境には、この**ee-terraform**を指定してください

(商用のAnsible（AAP)を使っているため、BaseImageはRHEL8ベースのものを使っていますが、Community版のAnsible AWXで使っているCentOSかなにかのベースイメージを使っても良いと思います)

### 2.事前準備② 認証情報の設定（２個）
設定するのはAWSのアクセスキー／シークレットアクセスキーと、EC2用キーペアの2個

@Ansible Controller、リソース-認証情報から新規認証情報を追加
(Terraform処理をするiac_aws_p1.ymlと動的インベントリで必要)
- 名前: 任意(ここでは**aws-auth**と仮に設定)
- 認証情報タイプ: Amazon Web Services
- アクセスキー: AWS Access Key ID
- シークレットキー: AWS Access Secret Key

@Ansible Controller、リソース-認証情報から新規認証情報を追加
(Ansible処理がEC2にSSH接続する時(iac_aws_p2.yml)に必要)
- 名前: 任意(ここでは**ec2-keypair**と仮に設定)
- 認証情報タイプ: Machine
- SSH秘密鍵: EC2のKeypairファイルをアップロード(Terraformスクリプトのkey_name=keypairファイル名で指定しているKeypairファイル)

### 3.事前準備③ AWS EC2用動的インベントリの設定

@Ansible Controller、リソース-インベントリーから新規インベントリーを追加
- 名前: 任意(ここでは**ec2-inventory**と仮に設定)

一度保存して、ec2-inventoryのソースを新規追加
- 認証情報: **aws-auth**
- 変数:
```playbook
ansible_python_interpreter: /usr/bin/python3
regions:
  - ap-northeast-1

keyed_groups:
  - prefix: tag
    key: tags
```
- 有効なオプション: 上書き、起動時の更新

(↑起動時の更新オプションが、Ansible-playbookから実行する場合のansible.builtin.meta: refresh_inventory代わりとなり、Terraformで作ったEC2がインベントリに反映されて、後続のAnsible処理で使えるようになる)

### 4.事前準備④ Projectの設定（コード置き場）
AnsibleもTerraformも１つのGitリポジトリに放り込むスタイル

@Ansible Controller、リソース-プロジェクトから新規プロジェクトを追加
名前: 任意(ここでは**ansible-terraform-project**と仮に設定)
ソースコントロールのタイプ: Git
ソースコントロールのURL: 本Gitリポジトリ

### 5.事前準備⑤ Templateの設定（Playbookジョブ、前述の通り2パート構成なので2個、ワークフローで統合）

@Ansible Controller、リソース-テンプレートから新規ジョブテンプレートを追加
- ジョブタイプ: 実行 
- インベントリ: 
- プロジェクト: **ansible-terraform-project** 
- 実行環境: **ee-terraform**
- Playbook: iac_aws_p1.yml
- 認証情報: **aws-auth**

@Ansible Controller、リソース-テンプレートから新規ジョブテンプレートを追加
- ジョブタイプ: 実行
- インベントリ: **ec2-inventory**
- プロジェクト: **ansible-terraform-project**
- 実行環境: **ee-terraform**
- Playbook: iac_aws_p2.yml
- 認証情報: **ec2-keypair**

### 6.いよいよ処理実行
上記のTemplate２つを順番に実行すると、TerraformでEC2が作成されて、Ansibleでモジュールインストール＆設定処理が行われます

Workflow templateにより、一連の流れとして統合可能です
（Ansibleコマンドから実行する場合同様、インベントリの連携はシームレスにできます）

## その他
Ansibleの処理対象は、Terraform側で設定したタグで、AWSのEC2リストを絞りこんで検知するスタイルなんですが、タグ指定、タグ絞り込み部分が、PlaybookとHCLでそれぞれハードコードになっているのが良くないか、、せめてパラメーター化したい

以上