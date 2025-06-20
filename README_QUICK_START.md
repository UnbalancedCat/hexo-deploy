# Hexo Blog Docker Quick Start Hexo Blog Docker 快速入门

**Version 版本**: v0.0.3 (Stable 稳定版) | **Status 状态**: 🟢 Production Ready 生产就绪 | **Updated 更新**: 2025-05-30

This guide provides a streamlined approach to deploying your Hexo blog using Docker. 本指南提供了一种使用 Docker 部署 Hexo 博客的简化方法。

## 🌟 Core Features 核心特性

- **One-Click Deployment 一键部署**: `docker build` & `docker run` for instant setup. 使用 `docker build` 和 `docker run` 即时设置。
- **Integrated SSH Server 集成SSH服务器**: For secure Git-based deployment. 用于安全的基于 Git 的部署。
- **Automated Health Checks 自动健康检查**: Ensures container reliability. 确保容器可靠性。
- **Smart Log Management 智能日志管理**: Automatic rotation and size control. 自动轮换和大小控制。

## 🚀 Quick Launch 快速启动

1.  **Prerequisites 前置条件**:
    *   Docker installed and running. Docker 已安装并正在运行。
    *   Ports `8080` (HTTP) and `2222` (SSH) are available. 端口 `8080` (HTTP) 和 `2222` (SSH) 可用。

2.  **Build & Run 构建与运行**:
    ```powershell
    # Navigate to the directory containing Dockerfile_v0.0.3 导航到包含 Dockerfile_v0.0.3 的目录
    # cd /path/to/your/hexo-docker-project

    # Build the Docker image 构建 Docker 镜像
    docker build -f Dockerfile_v0.0.3 -t hexo-blog:v0.0.3 .

    # Run the container 运行容器
    docker run -d --name hexo-blog --restart unless-stopped -p 8080:80 -p 2222:22 hexo-blog:v0.0.3
    ```

3.  **Verify 验证**:
    *   Blog: http://localhost:8080
    *   Health: http://localhost:8080/health
    *   Container Status 容器状态: `docker ps | findstr hexo-blog` (Should show `Up (healthy)` 应该显示 `Up (healthy)`)

## 🔑 SSH Deployment Setup SSH 部署设置

1.  **Generate SSH Key 生成 SSH 密钥** (if you don\'t have one 如果你没有): 
    ```powershell
    ssh-keygen -t rsa -b 2048 -f ./hexo_deploy_key -N ""
    # This creates hexo_deploy_key and hexo_deploy_key.pub 这将创建 hexo_deploy_key 和 hexo_deploy_key.pub
    ```

2.  **Add Public Key to Container 将公钥添加到容器**:
    ```powershell
    # Copy public key content 复制公钥内容
    Get-Content ./hexo_deploy_key.pub | docker exec -i hexo-blog bash -c "mkdir -p /home/hexo/.ssh && cat >> /home/hexo/.ssh/authorized_keys && chmod 600 /home/hexo/.ssh/authorized_keys && chmod 700 /home/hexo/.ssh && chown -R hexo:hexo /home/hexo/.ssh"
    ```

3.  **Configure Git Remote 配置 Git 远程** (in your Hexo blog directory 在你的 Hexo 博客目录中):
    ```bash
    git remote add docker ssh://hexo@localhost:2222/home/hexo/hexo.git
    ```

4.  **Deploy 部署**:
    ```powershell
    # Set GIT_SSH_COMMAND to use your private key 设置 GIT_SSH_COMMAND 以使用您的私钥
    $env:GIT_SSH_COMMAND = "ssh -i $(Resolve-Path ./hexo_deploy_key) -o IdentitiesOnly=yes -o StrictHostKeyChecking=no"
    git push docker main # Or your branch 或者你的分支
    ```

## 📖 Further Reading 延伸阅读

- **Simple Quick Start 简单快速入门**: For the absolute fastest way to get started, see [README_QUICK_START_SIMPLE.md](README_QUICK_START_SIMPLE.md).
- **Complete Quick Start 完整快速入门**: For more details and advanced options, refer to [README_QUICK_START_COMPLETE.md](README_QUICK_START_COMPLETE.md).
- **Main README 主 README**: For comprehensive project information, see [README.md](README.md).
- **Chinese README 中文 README**: 中文用户请参考 [README_zh.md](README_zh.md).

## 🐳 Useful Docker Commands 有用的 Docker 命令

- **View Logs 查看日志**: `docker logs hexo-blog`
- **Stop Container 停止容器**: `docker stop hexo-blog`
- **Remove Container 移除容器**: `docker rm hexo-blog`
- **Restart Container 重启容器**: `docker restart hexo-blog`
- **Enter Container Shell 进入容器 Shell**: `docker exec -it hexo-blog bash`

---
**Status 状态**: 🟢 Production Ready 生产就绪 | **Version 版本**: v0.0.3
