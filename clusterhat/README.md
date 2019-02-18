# Hypriot

- Use Hypriot 1.10-rc2 or later
- Flash it with https://github.com/hypriot/flash
- ClusterHAT v2

## Build

Run the `build.sh` script if you have docker, otherwise use `make`, output is in `./build`

Flash the controller

```bash
flash -C source/controller/config.txt --userdata build/controller/user-data hypriotos-rpi-v1.10.0-rc2.img.zip
```

Then flash your Zeros with the following command where <NODE> is one of [p1,p2,p3,p4]

```bash
flash -C source/cluster-nodes/config.txt --userdata build/<NODE>/user-data hypriotos-rpi-v1.10.0-rc2.img.zip
```

Then copy `cmdline.txt` to the image boot directory after successful flash from above command.

## Connect to Zeros and make a Swarm

The controller is a NAT gateway for the zeros, to access any of them use `172.19.181.X` where X is 1-4.
Or you can use pX as a hostname.

Run the following to join each Zero to the Swarm

```bash
TOKEN=$(docker swarm join-token worker -q)
ssh p1 docker swarm join --token $TOKEN 192.168.1.30:2377
ssh p2 docker swarm join --token $TOKEN 192.168.1.30:2377
ssh p3 docker swarm join --token $TOKEN 192.168.1.30:2377
ssh p4 docker swarm join --token $TOKEN 192.168.1.30:2377
```

Confirm all nodes are in the Swarm

```bash
HypriotOS/armv7: mchestr@controller in ~
$ docker node ls
ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
pi9y9zvvnfqmyxl5wr6cjrs97 *   controller          Ready               Active              Leader              18.06.1-ce
mnwtrbq3npersoy6ya8ibwq62     p1                  Ready               Active                                  18.06.1-ce
xv35c7z7vjy86rx6v27elb4cg     p2                  Ready               Active                                  18.06.1-ce
bkjdji2dnwkqmryuuwwu5mpz2     p3                  Ready               Active                                  18.06.1-ce
```

## cloud-init

Files must start with `#cloud-config` to be valid configuration.

Validate on [CoreOs](https://coreos.com/validate/)
