# ExpressVPN

Container-based on [polkaned/expressvpn](https://hub.docker.com/r/polkaned/expressvpn) version. This is my attempt mostly to learn more about docker.

ExpressVPN version: `3.14.0.4`
Currently set to use `lightway_udp` protocol with `chacha20` cipher.

## NETWORK_LOCK

Currently, `network_lock` is turned on by default but in case of any issues you can turn it off by setting env variable `NETWORK` to `off`.
In most cases when `network_lock` cannot be used it is caused by old kernel version. Apparently, the minimum kernel version where `network_lock` is supported is **4.9**.

*As of version 3.13.0.8 and higher a script is included that checks if the host's kernel version meets minimum requirements to allow `network_lock`. If not and the user sets or leaves the default setting `network_lock` to `on`, then `network_lock` will be disabled to allow expressvpn to run.*

## WHITELIST_DNS

As of `3.14.0.4` new env is available. It can be used like in the examples below and it is a comma seperated list of dns servers you wish to use and whitelist via iptables. Leave empty for default behavior.

## HEALTHCHECK
Healthcheck is performed once every 2min.
You can also add `--env=DDSN=domain` or `--env=IP=yourIP` to docker run command or in the environment section of compose in order to perform healthcheck which will be checking if data from env variable DDNS or IP is different than ExpressVPN's IP.
If you won't set any of them, by default healthcheck will return status `healthy`.
Also, there is a possibility to add `--env=BEAERER=access_token` from [ipinfo.io](https://ipinfo.io/) if you have an account there (free plan gives you 50k requests per month).

Additionally, healthchecks.io support has been added and you can add the id of the healthchecks link to the `HEALTHCHECK` variable in docker configs.

## Build

**AMD64**
`docker buildx build --build-arg NUM=EXPRESSVPN_VERSION --build-arg PLATFORM=amd64 --platform linux/amd64 -t REPOSITORY/APP:VERSION .`

**Raspberry Pi**
`docker buildx build --build-arg NUM=EXPRESSVPN_VERSION --build-arg PLATFORM=armhf --platform linux/arm/v7 -t REPOSITORY/APP:VERSION-armhf .`

## Download

`docker pull misioslav/expressvpn`

## Start the container

```
    docker run \
    --env=WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8 \
    --env=CODE=CODE \
    --env=SERVER=SMART \
    --cap-add=NET_ADMIN \
    --device=/dev/net/tun \
    --privileged \
    --detach=true \
    --tty=true \
    --name=expressvpn \
    --publish 80:80 \
    --env=DDNS=domain \ #optional
    --env=IP=yourIP \ #optional
    --env=BEARER=ipinfo_access_token \ #optional
    --env=NETWORK=on/off \ #optional set to on by default
    misioslav/expressvpn \
    /bin/bash
```


Another container that will use ExpressVPN network:

```
    docker run \
    --name=example \
    --net=container:expressvpn \
    maintainer/example:version
```

## Docker Compose

```
  example:
    image: maintainer/example:version
	container_name: example
	network_mode: service:expressvpn
	depends_on:
	  - expressvpn

  expressvpn:
    image: misioslav/expressvpn:latest
    container_name: expressvpn
    restart: unless-stopped
    ports: # ports from which container that uses expressvpn connection will be available in local network
      - 80:80 # example
    environment:
      - WHITELIST_DNS=192.168.1.1,1.1.1.1,8.8.8.8  # Comma seperated list of dns servers you wish to use and whitelist via iptables
      - CODE=${CODE} # Activation Code from ExpressVPN https://www.expressvpn.com/support/troubleshooting/find-activation-code/
      - SERVER=SMART # By default container will connect to smart location, list of available locations you can find below
      - DDNS=yourDDNSdomain # optional
      - IP=yourStaticIP # optional - won't work if DDNS is setup
      - BEAERER=ipinfo_access_token # optional can be taken from ipinfo.io
      - HEALTHCHECK=HEALTCHECKS.IO_ID # optional can be taken from healthchecks.io
      - NETWORK=off/on #optional and set to on by default
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    stdin_open: true
    tty: true
    command: /bin/bash
    privileged: true
```

## SERVERS AVAILABLE

You can choose to which location ExpressVPN should connect to by setting up `SERVER=ALIAS/COUNTRY/LOCATION/SMART`
Check the table below for the full list of available servers to connect to.
You can also check available locations from inside the container by running `expressvpn list all` command.

```
ALIAS COUNTRY                     LOCATION                       
----- ---------------             ------------------------------
smart Smart Location              Poland                        
in    India (IN)                  India (via UK)                
inmu1                             India - Mumbai - 1             
inch                              India - Chennai                
pl    Poland (PL)                 Poland                        
cz    Czech Republic (CZ)         Czech Republic                
usny  United States (US)          USA - New York                
uswd                              USA - Washington DC           
usla2                             USA - Los Angeles - 2         
usnj3                             USA - New Jersey - 3          
ussf                              USA - San Francisco            
usch                              USA - Chicago                  
usda                              USA - Dallas                   
usmi                              USA - Miami                    
usla3                             USA - Los Angeles - 3          
usnj1                             USA - New Jersey - 1           
usse                              USA - Seattle                  
usmi2                             USA - Miami - 2                
usde                              USA - Denver                   
ussl1                             USA - Salt Lake City           
usta1                             USA - Tampa - 1                
usla1                             USA - Los Angeles - 1          
usnj2                             USA - New Jersey - 2           
usda2                             USA - Dallas - 2               
usla                              USA - Los Angeles              
usat                              USA - Atlanta                  
usla5                             USA - Los Angeles - 5          
ussm                              USA - Santa Monica             
sgju  Singapore (SG)              Singapore - Jurong             
sgcb                              Singapore - CBD                
sgmb                              Singapore - Marina Bay         
frst  France (FR)                 France - Strasbourg           
frpa2                             France - Paris - 2             
fral                              France - Alsace                
hk2   Hong Kong (HK)              Hong Kong - 2                  
hk1                               Hong Kong - 1                  
ukdo  United Kingdom (GB)         UK - Docklands                
ukel                              UK - East London              
uklo                              UK - London                    
ukwe                              UK - Wembley                   
jpto  Japan (JP)                  Japan - Tokyo                  
jpyo                              Japan - Yokohama               
jpto2                             Japan - Tokyo - 2              
se    Sweden (SE)                 Sweden                        
se2                               Sweden - 2                     
itco  Italy (IT)                  Italy - Cosenza               
aume  Australia (AU)              Australia - Melbourne          
ausy                              Australia - Sydney             
aupe                              Australia - Perth              
aubr                              Australia - Brisbane           
ausy2                             Australia - Sydney - 2         
denu  Germany (DE)                Germany - Nuremberg           
defr1                             Germany - Frankfurt - 1        
defr3                             Germany - Frankfurt - 3        
nlam2 Netherlands (NL)            Netherlands - Amsterdam - 2   
nlth                              Netherlands - The Hague       
nlam                              Netherlands - Amsterdam        
nlro                              Netherlands - Rotterdam        
kr2   South Korea (KR)            South Korea - 2                
ph    Philippines (PH)            Philippines                    
my    Malaysia (MY)               Malaysia                       
lk    Sri Lanka (LK)              Sri Lanka                      
pk    Pakistan (PK)               Pakistan                       
kz    Kazakhstan (KZ)             Kazakhstan                     
th    Thailand (TH)               Thailand                       
id    Indonesia (ID)              Indonesia                      
nz    New Zealand (NZ)            New Zealand                    
tw3   Taiwan (TW)                 Taiwan - 3                     
vn    Vietnam (VN)                Vietnam                        
mo    Macau (MO)                  Macau                          
kh    Cambodia (KH)               Cambodia                       
mn    Mongolia (MN)               Mongolia                       
la    Laos (LA)                   Laos                           
mm    Myanmar (MM)                Myanmar                        
np    Nepal (NP)                  Nepal                          
kg    Kyrgyzstan (KG)             Kyrgyzstan                     
uz    Uzbekistan (UZ)             Uzbekistan                     
bd    Bangladesh (BD)             Bangladesh                     
bt    Bhutan (BT)                 Bhutan                         
bnbr  Brunei Darussalam (BN)      Brunei                         
cato  Canada (CA)                 Canada - Toronto               
cava                              Canada - Vancouver             
cato2                             Canada - Toronto - 2           
camo                              Canada - Montreal              
mx    Mexico (MX)                 Mexico                         
br2   Brazil (BR)                 Brazil - 2                     
br                                Brazil                         
pa    Panama (PA)                 Panama                         
cl    Chile (CL)                  Chile                          
ar    Argentina (AR)              Argentina                      
bo    Bolivia (BO)                Bolivia                        
cr    Costa Rica (CR)             Costa Rica                     
co    Colombia (CO)               Colombia                       
ve    Venezuela (VE)              Venezuela                      
ec    Ecuador (EC)                Ecuador                        
gt    Guatemala (GT)              Guatemala                      
pe    Peru (PE)                   Peru                           
uy    Uruguay (UY)                Uruguay                        
bs    Bahamas (BS)                Bahamas                        
ch    Switzerland (CH)            Switzerland                    
ro    Romania (RO)                Romania                        
im    Isle of Man (IM)            Isle of Man                    
esma  Spain (ES)                  Spain - Madrid                 
esba                              Spain - Barcelona              
esba2                             Spain - Barcelona - 2          
tr    Turkey (TR)                 Turkey                         
ie    Ireland (IE)                Ireland                        
is    Iceland (IS)                Iceland                        
no    Norway (NO)                 Norway                         
dk    Denmark (DK)                Denmark                        
be    Belgium (BE)                Belgium                        
fi    Finland (FI)                Finland                        
gr    Greece (GR)                 Greece                         
pt    Portugal (PT)               Portugal                       
at    Austria (AT)                Austria                        
am    Armenia (AM)                Armenia                        
lt    Lithuania (LT)              Lithuania                      
lv    Latvia (LV)                 Latvia                         
ee    Estonia (EE)                Estonia                        
ad    Andorra (AD)                Andorra                        
me    Montenegro (ME)             Montenegro                     
ba    Bosnia and Herzegovina (BA) Bosnia and Herzegovina         
lu    Luxembourg (LU)             Luxembourg                     
hu    Hungary (HU)                Hungary                        
bg    Bulgaria (BG)               Bulgaria                       
by    Belarus (BY)                Belarus                        
ua    Ukraine (UA)                Ukraine                        
mt    Malta (MT)                  Malta                          
li    Liechtenstein (LI)          Liechtenstein                  
cy    Cyprus (CY)                 Cyprus                         
al    Albania (AL)                Albania                        
hr    Croatia (HR)                Croatia                        
si    Slovenia (SI)               Slovenia                       
sk    Slovakia (SK)               Slovakia                       
mc    Monaco (MC)                 Monaco                         
je    Jersey (JE)                 Jersey                         
mk    North Macedonia (MK)        North Macedonia                
md    Moldova (MD)                Moldova                        
rs    Serbia (RS)                 Serbia                         
ge    Georgia (GE)                Georgia                        
za    South Africa (ZA)           South Africa                   
il    Israel (IL)                 Israel                         
eg    Egypt (EG)                  Egypt                          
ke    Kenya (KE)                  Kenya                          
dz    Algeria (DZ)                Algeria  
```
