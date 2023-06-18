---
title: "Ios Code Lint"
date: 2023-06-14T16:41:45+08:00
draft: true
---

#### iOS代码审查

- [OCLint](https://oclint.org/)

- [SwiftLint](https://github.com/realm/SwiftLint/)

- [eslint](https://eslint.org/)


#### GitLab工作流集成

- [Gitlab Guild](https://docs.gitlab.com/)
    - [CI/CD](https://docs.gitlab.com/ee/ci/yaml/)
    - [Local-CI](https://gzoffice.mojidict.com:8000/help/ci/quick_start/index.md)

- YAML
    YAML 是一种人类可读的数据序列化格式，常用于配置文件和数据传输。在 `GitLab` 中，`.gitlab-ci.yml` 文件用于定义 `CI/CD` 流水线的配置;
    YAML 对缩进非常敏感，使用空格进行缩进，一般推荐使用 2 个空格作为缩进单位。此外，还可以使用 YAML 的其他特性，如环境变量、条件语句、循环等，以满足更复杂的流水线配置需求

在项目根目录创建`.gitlab-ci.yml`文件，在`.gitlab-ci.yml`文件中定义工作流配置


- 第三方模板

    GitLab CI/CD Configuration Templates: https://gitlab.com/gitlab-org/gitlab-ci-templates
    GitLab CI/CD Configuration Generator: https://gitlab.com/gitlab-org/gitlab-ci-cd-config-generator
    

- 配置模板

``` yaml
    stages:
  - build
  - test
  - deploy

job1:
  stage: build
  script:
    - echo "Building..."

job2:
  stage: test
  script:
    - echo "Testing..."

job3:
  stage: deploy
  script:
    - echo "Deploying..."
```

在上述示例中，stages 定义了流水线中的阶段，job1、job2 和 job3 分别定义了流水线中的作业。每个作业都有一个 stage 字段指定所属的阶段，并且有一个 script 字段定义作业的执行脚本

#### 本地测试Gitlab工作流

- [GitLab Runner](https://docs.gitlab.com/runner/install/osx.html)

安装`brew install gitlab-runner`
启动`brew services start gitlab-runner`


#### 将XLint集成到工作流
