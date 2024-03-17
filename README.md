# beginner-de-project

## Description
This repository serves as my learning material for developing Data Engineering (DE) skills, focusing on Airflow, Docker, AWS cloud computing, and data pipeline best practices.

Credit goes to [@josephmachado](https://github.com/josephmachado) for initially setting up this project. You can find his repository [here](https://github.com/josephmachado/beginner_de_project).

## Status
Ongoing

### Struggle
Encountered issues with Airflow connectivity after running `make infra-up`.

## What I Have Done and Learned

1. **Setting up WSL and Ubuntu on Windows:**
    - Utilized [Microsoft's guide](https://learn.microsoft.com/en-gb/windows/wsl/install) for setting up WSL.
    - Installed Docker Desktop for Windows following the instructions provided [here](https://docs.docker.com/desktop/install/windows-install/).

2. **Setting up AWS Account and AWS CLI:**
    - Followed the steps outlined in the AWS documentation's ["Getting Started" guide](https://aws.amazon.com/getting-started/guides/setup-environment/module-one/), focusing on module three.

3. **AWS SSO Configuration:**
    - Configured AWS SSO as a separate profile instead of using the default one.
    - Encountered issues with Terraform due to this setup.
    - After setting up SSO, it's necessary to change the profile in `main.tf` to your SSO name.
    - Also, commented out sections 'a' and 'b' in `~/.aws/config`.
    - Refer to [this issue](https://github.com/hashicorp/terraform/issues/32448#issuecomment-1505575049) for more details.

4. **EMR Default Role Setup:**
    - Encountered a missing default role issue with EMR.
    - Resolved it using the command line: `aws emr create-default-roles` in the AWS console.

5. **S3 ACL Error Resolution:**
    - Faced S3 ACL errors during deployment.
    - Followed steps outlined [here](https://medium.com/terraform-aws-tips/aws-disabled-s3-acl-88d8976df26e) to resolve the issue.

## Contact
For any queries or suggestions regarding this project, feel free to contact me.
