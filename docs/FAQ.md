## Frequently asked questions


### How can I access a GUI or a service endpoint of a POD running in the ABM cluster without exposing with a load balancer  ?

1st ssh into the cnuc1:

1. ssh into `cnuc-1` as abm-admin user.

1. Port forward with bind address . Do this as root of you want port 80 (standard port). Otherwise use different port
    ```bash
    kubectl -n longhorn-system port-forward --address 0.0.0.0 longhorn-ui-5b864949c4-plwwg 80:8000
    ```
1. Setup a `firewall rule` to allow port 80 or whichever port you used in earlier step

1. Find the public IP of the cnuc-1 and access the port like `http://cnuc-1-external-ip:port`


```bash
python -m pip install --user "molecule[ansible,docker,lint,gce]"
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```

### What external URLs are required to be allowlisted?

1. The following should be opened up to the machines running this solution:


| Service | Port | Protocol | URL/URI | Description |
| --- | --- | --- | --- | --- |
| Google Container Registry | 443 | tcp | *.gcr.io | Google container registry used for solution artifacts and customer applications |
| Google Services | 443 | tcp | *.googleapis.com | Google Services like GKE Hub, CloudOps, Secrets Manager, IAM, Compute, Network, etc |
| Gitlab SaaS | 443 | tcp | gitlab.com | Repositories used by default solution (change with other git service provider as needed) |
| Ubuntu Pacakges Manager (aptitude) | 443 | tcp | *.ubuntu.com | Package manager for Ubuntu |
| Ubuntu Package Manager (Snap) | 443 | tcp | *.canonical.com, *.snapcraft.io | Package manager for Ubuntu and Canonical services via Snap |
| Docker Hub | 443 | tcp | download.docker.com | Docker Hub mostly for OSS libraries |
| Google Packages | 443 | tcp | packages.cloud.google.com | Google CLI tools and libraries supporting tools |

