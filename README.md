## Instructions:

*While I recognize that this might not be the optimal solution, it effectively serves as a valuable proof of concept (POC).*

**Technologies Used**:

- **Terraform**: Utilized for infrastructure-as-code deployment.
- **EC2**: Amazon Elastic Compute Cloud, offering scalable computing capacity.
- **Prometheus**: Open-source monitoring and alerting toolkit.
- **Grafana**: Open-source platform for monitoring and observability.
- **ECS**: Amazon Elastic Container Service, managing Docker containers at scale.
- **ECR**: Amazon Elastic Container Registry, storing Docker container images.
- **Docker**: Platform to develop, ship, and run applications inside containers.
- **Docker Compose**: Tool for defining and managing multi-container Docker applications.
- **Python**: Scripting for service discovery. <---> This was fun...

**Setup & Deployment**:

1. Adjust the variables to align with your specific objectives.

2. Execute the following commands sequentially:
   - `terraform init`
   - `terraform plan`
   - `terraform apply`

3. Navigate to the app folder: `cd app`

4. Execute `./push-to-ecr.sh` with your credentials.

![image info](images/script_variables.png)

This can also be done manually, utilizing the push commands.

![image info](images/push_commands.png)

Once done, access the application through the load balancer endpoint, available in the outputs inside of the terminal. It should present you with a "hello world" display.

Outputs:
![image info](images/outputs.png)

**EC2 Configuration**:

The EC2 instance benefits from bootstrapping via user data. However, some manual interventions are essential:

1. Update the Prometheus configuration target using your load balancer endpoint. You can achieve this by revising the user data within the EC2 resource, replacing `<YOUR-LOAD-BALANCER-HERE>`.

2. Reapply Terraform: `terraform apply`

3. Post-configuration, Grafana can be accessed at `<EC2-Public-IP>:3000` and Prometheus at `<EC2-Public-IP>:9090`.

**Sidenote**: Multiple solutions exist for this configuration. However, to ensure clarity and employ minimal services and simplicity for this project, I opted for this particular approach.

**Sidenote Sidenote**: You may have to exec into the SSH into the instance and run `sudo docker-compose up` manually.

![image info](images/docker-compose.png)

**Sidenote Sidenote Sidenote**: If you need further insights into your application, you can view the Cloudwatch logs:

![image info](images/cloudwatch.png)

---

## My Journey with the Project

The project was a roller coaster of learning experiences. Despite some initial missteps, it evolved into a valuable growth opportunity for me.

###  **Diving into Unknown Waters with AMP and ECS**
My journey commenced with research on implementing Prometheus in ECS using AMP—a tool I hadn't interfaced with before. Although scant and at times convoluted information was available, mostly oriented towards EKS and not ECS, it was crucial to stick to native resources, avoiding any makeshift solutions.

###  **The Overlooked Console Feature**
A recent, in-console ADOT task definition feature, could have streamlined my process. However, I only stumbled upon it post-completion.

![image info](images/console.png)

###  **Embarking with Terraform**
With what appeared as the simpler tasks at hand, I delved into deploying an ECS cluster and task using Terraform. Despite being mostly boilerplate, it marked the initiation of the project's practical phase.

###  **Opting for a Simple JS Express App**
For full control and simplicity, I utilized a basic JavaScript Express app. This decision saved me from intricate configurations and metric adjustments.

###  **Metrics Collection: The Ups and Downs**
Beginning with default metrics was straightforward—integrate the Prometheus client and direct metrics to the `/metrics` endpoint. However, an oversight led me down a convoluted path of sidecars, erroneous node exporter metrics, and misinterpreted endpoints. The complexities even had me constructing a custom service discovery using Python and cronjobs—turns out, it wasn't necessary.

###  **Returning to Basics**
Removing the sidecar brought clarity. My understanding had been clouded by routing conflicts within the load balancer. Addressing it unlocked access to the metrics.

![image info](images/metrics.png)

### 🌟 **The Final Steps: Prometheus and Terraform**
With metrics in hand, the subsequent tasks were simpler: set up a Prometheus instance and configure it for the load balancer. Leveraging Docker-compose, a consistent ally in my toolkit, I fashioned a promgraf stack—a helm chart equivalent in this context. With everything functional, all that remained was harnessing Terraform.

Examples:

**Graph**
![image info](images/graph.png)

**Alert**
![image info](images/alert_rule_triggered.png)
