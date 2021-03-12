# ExpressVPN

Container based on [polkaned/expressvpn](https://hub.docker.com/r/polkaned/expressvpn) version. This is my attempt mostly to learn more about docker.

ExpressVPN version: `expressvpn_3.6.0.70-1_amd64.deb`

## Download

`docker pull misioslav/expressvpn`

## Start the container

```
    docker run \
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
	    - CODE=${CODE} # Activation Code from ExpressVPN https://www.expressvpn.com/support/troubleshooting/find-activation-code/
	    - SERVER=SMART # By default container will connect to smart location, list of available locations you can find below
	    - DDNS=yourDDNSdomain # optional
	    - IP=yourStaticIP # optional - won't work if DDNS is setup
	    - BEAERER=ipinfo_access_token # optional can be taken from ipinfo.io
    	- HEALTHCHECK=HEALTCHECKS.IO_ID # optional can be taken from healthchecks.io
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    stdin_open: true
    tty: true
    command: /bin/bash
    privileged: true
```

## HEALTHCHECK
Healthcheck is performed once every 2min.
You can also add `--env=DDSN=domain` or `--env=IP=yourIP` to docker run command or in enviroment section of compose in order to perform healthcheck which will be checking if data from env variable DDNS or IP is different than ExpressVPN's IP.
If you won't set any of them, by default healthcheck will return status `healthy`.
Also, there is a possibility to add `--env=BEAERER=access_token` from [ipinfo.io](https://ipinfo.io/) if you have an account there (free plan gives you 50k requests per month).

Additionally, healthchecks.io support has been added and you can add id of the healthchecks link to `HEALTHCHECK` variable in docker configs.

## SERVER

You can choose to which location ExpressVPN should connect to by setting up `SERVER=ALIAS/COUNTRY/LOCATION/SMART`
Check the table below for the full list of available servers to connect to.
You can also check available locations from inside the container by running `expressvpn list all` command.

```
ALIAS COUNTRY                     LOCATION                       
----- ---------------             ------------------------------
smart smart location
in    India                       India (via UK)  
inmu1                             India - Mumbai - 1             
inch                              India - Chennai                
pl    Poland                      Poland          
cz    Czech Republic              Czech Republic  
frst  France                      France - Strasbourg
frpa2                             France - Paris - 2             
sgju  Singapore                   Singapore - Jurong             
sgcb                              Singapore - CBD                
sgmb                              Singapore - Marina Bay         
ukdo  United Kingdom              UK - Docklands     
ukel                              UK - East London   
uklo                              UK - London                    
ukwe                              UK - Wembley                   
usny  United States               USA - New York     
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
usho                              USA - Hollywood                
usda2                             USA - Dallas - 2               
usla                              USA - Los Angeles              
usat                              USA - Atlanta                  
usla5                             USA - Los Angeles - 5          
ussm                              USA - Santa Monica             
hk2   Hong Kong                   Hong Kong - 2                  
hk4                               Hong Kong - 4                  
hk1                               Hong Kong - 1                  
jpto  Japan                       Japan - Tokyo                  
jpyo                              Japan - Yokohama               
jpto2                             Japan - Tokyo - 2              
se    Sweden                      Sweden               
se2                               Sweden - 2                    
itco  Italy                       Italy - Cosenza      
denu  Germany                     Germany - Nuremberg  
defr1                             Germany - Frankfurt - 1        
defr3                             Germany - Frankfurt - 3        
aume  Australia                   Australia - Melbourne          
ausy                              Australia - Sydney             
aupe                              Australia - Perth              
aubr                              Australia - Brisbane           
ausy2                             Australia - Sydney - 2         
nlam2 Netherlands                 Netherlands - Amsterdam - 2
nlth                              Netherlands - The Hague    
nlam                              Netherlands - Amsterdam       
nlro                              Netherlands - Rotterdam        
kr2   South Korea                 South Korea - 2                
ph    Philippines                 Philippines                    
my    Malaysia                    Malaysia                       
lk    Sri Lanka                   Sri Lanka                      
kz    Kazakhstan                  Kazakhstan                     
th    Thailand                    Thailand                       
id    Indonesia                   Indonesia                      
nz    New Zealand                 New Zealand                    
tw3   Taiwan                      Taiwan - 3                     
vn    Vietnam                     Vietnam                        
mo    Macau                       Macau                          
kh    Cambodia                    Cambodia                       
mn    Mongolia                    Mongolia                       
la    Laos                        Laos                           
mm    Myanmar                     Myanmar                        
np    Nepal                       Nepal                          
kg    Kyrgyzstan                  Kyrgyzstan                     
uz    Uzbekistan                  Uzbekistan                     
bd    Bangladesh                  Bangladesh                     
bt    Bhutan                      Bhutan                         
bnbr  Brunei Darussalam           Brunei                         
cato  Canada                      Canada - Toronto               
cava                              Canada - Vancouver             
cato2                             Canada - Toronto - 2           
camo                              Canada - Montreal              
mx    Mexico                      Mexico                         
br2   Brazil                      Brazil - 2                     
br                                Brazil                         
pa    Panama                      Panama                         
cl    Chile                       Chile                          
ar    Argentina                   Argentina                      
cr    Costa Rica                  Costa Rica                     
co    Colombia                    Colombia                       
ve    Venezuela                   Venezuela                      
ec    Ecuador                     Ecuador                        
gt    Guatemala                   Guatemala                      
pe    Peru                        Peru                           
uy    Uruguay                     Uruguay                        
ch    Switzerland                 Switzerland                    
ro    Romania                     Romania                        
im    Isle of Man                 Isle of Man                    
esma  Spain                       Spain - Madrid                 
esba                              Spain - Barcelona              
esba2                             Spain - Barcelona - 2          
tr    Turkey                      Turkey                         
ie    Ireland                     Ireland                        
is    Iceland                     Iceland                        
no    Norway                      Norway                         
dk    Denmark                     Denmark                        
be    Belgium                     Belgium                        
fi    Finland                     Finland                        
gr    Greece                      Greece                         
pt    Portugal                    Portugal                       
at    Austria                     Austria                        
am    Armenia                     Armenia                        
lt    Lithuania                   Lithuania                      
lv    Latvia                      Latvia                         
ee    Estonia                     Estonia                        
ad    Andorra                     Andorra                        
me    Montenegro                  Montenegro                     
ba    Bosnia and Herzegovina      Bosnia and Herzegovina         
lu    Luxembourg                  Luxembourg                     
hu    Hungary                     Hungary                        
bg    Bulgaria                    Bulgaria                       
by    Belarus                     Belarus                        
ua    Ukraine                     Ukraine                        
mt    Malta                       Malta                          
li    Liechtenstein               Liechtenstein                  
cy    Cyprus                      Cyprus                         
al    Albania                     Albania                        
hr    Croatia                     Croatia                        
si    Slovenia                    Slovenia                       
sk    Slovakia                    Slovakia                       
mc    Monaco                      Monaco                         
je    Jersey                      Jersey                         
mk    North Macedonia             North Macedonia                
md    Moldova                     Moldova                        
rs    Serbia                      Serbia                         
ge    Georgia                     Georgia                        
za    South Africa                South Africa                   
il    Israel                      Israel                         
eg    Egypt                       Egypt                          
ke    Kenya                       Kenya                          
dz    Algeria                     Algeria
```
