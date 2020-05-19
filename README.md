# ExpressVPN

Container based on [polkaned/expressvpn](https://hub.docker.com/r/polkaned/expressvpn) version. This is my attempt mostly to learn more about docker.

ExpressVPN version: `expressvpn_2.5.0.505-1_amd64.deb`

Take `misioslav/expressvpn:cron` if you prefer a cron job (runs once every 5min) to check the status of your connection.

Take `misioslav/expressvpn:latest` if you prefer to have a healthcheck performed every 2min (you may need an access_token for this. See **HEALTHCHECK** section).

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
    network_mode: bridge # change this if you want to use a different mode
    container_name: expressvpn
    restart: unless-stopped
    ports: # ports from which container that uses expressvpn connection will be available in local network
      - 80:80 # example
    environment:
      - CODE=${CODE} # Activation Code from ExpressVPN https://www.expressvpn.com/support/troubleshooting/find-activation-code/
      - SERVER=SMART # By default container will connect to smart location, list of available locations you can find below
	  - DDNS=domain # optional
	  - IP=yourIP # optional - won't work if DDNS is setup
	  - BEAERER=ipinfo_access_token # optional
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
Healthcheck is performed once every 30min.
You can also add `--env=DDSN=domain` or `--env=IP=yourIP` to docker run command or in enviroment section of compose in order to perform healthcheck which will be checking if data from env variable DDNS or IP is different than ExpressVPN's IP.
If you won't set any of them, by default healthcheck will return status `healthy`.
Also, there is a possibility to add `--env=BEAERER=access_token` from [ipinfo.io](https://ipinfo.io/) if you have an account there (free plan gives you 50k requests per month).

## SERVER

You can choose to which location ExpressVPN should connect to by setting up `SERVER=ALIAST/COUNTRY/LOCATION/SMART`
Check the table below for the full list of available servers to connect to.
You can also check available locations from inside the container by running `expressvpn list all` command.

```
ALIAS COUNTRY                     LOCATION                      
----- ---------------             ------------------------------
smart Smart Location              Germany - Frankfurt - 1
frpa1 France		              France - Paris - 1             
frst                              France - Strasbourg            
frpa2                             France - Paris - 2
inmu1 India		                  India - Mumbai - 1
in                                India (via UK)
inch                              India - Chennai
nlth  Netherlands	              Netherlands - The Hague        
nlro                              Netherlands - Rotterdam        
nlam                              Netherlands - Amsterdam
nlam2                             Netherlands - Amsterdam - 2
sgju  Singapore 	              Singapore - Jurong
sgcb                              Singapore - CBD
sgmb                              Singapore - Marina Bay
ukdo  United Kingdom 	          UK - Docklands                 
ukel                              UK - East London               
uklo                              UK - London
ukke                              UK - Kent
ukwe                              UK - Wembley
hk2   Hong Kong 	              Hong Kong - 2
hk3                               Hong Kong - 3
hk4                               Hong Kong - 4
usny  United States 	          USA - New York                 
uswd                              USA - Washington DC            
uswd2                             USA - Washington DC - 2        
usnj1                             USA - New Jersey - 1           
ussf                              USA - San Francisco
usch                              USA - Chicago
usda                              USA - Dallas
usmi                              USA - Miami
usla3                             USA - Los Angeles - 3
usla2                             USA - Los Angeles - 2
usnj3                             USA - New Jersey - 3
usse                              USA - Seattle
usmi2                             USA - Miami - 2
usde                              USA - Denver
ussl1                             USA - Salt Lake City
usta1                             USA - Tampa - 1
usla1                             USA - Los Angeles - 1
usny2                             USA - New York - 2
usnj2                             USA - New Jersey - 2
usda2                             USA - Dallas - 2
usla                              USA - Los Angeles
ussj                              USA - San Jose
usla5                             USA - Los Angeles - 5
usla4                             USA - Los Angeles - 4
ussm                              USA - Santa Monica
jpto1 Japan 	                  Japan - Tokyo - 1
jpka                              Japan - Kawasaki
jpto3                             Japan - Tokyo - 3
jpyo                              Japan - Yokohama
jpto2                             Japan - Tokyo - 2
se    Sweden 	                  Sweden                         
ch2   Switzerland 	              Switzerland - 2                
ch                                Switzerland
itmi  Italy 	                  Italy - Milan                  
itco                              Italy - Cosenza
denu  Germany 	                  Germany - Nuremberg            
defr1                             Germany - Frankfurt - 1
defr2                             Germany - Frankfurt - 2
defr3                             Germany - Frankfurt - 3
aume  Australia 	              Australia - Melbourne
ausy                              Australia - Sydney
aupe                              Australia - Perth
aubr                              Australia - Brisbane
ausy2                             Australia - Sydney - 2
kr2   South Korea 	              South Korea - 2
ph    Philippines 	              Philippines
my    Malaysia 	                  Malaysia
lk    Sri Lanka 	              Sri Lanka
pk    Pakistan 	                  Pakistan
kz    Kazakhstan 	              Kazakhstan
th    Thailand 	                  Thailand
id    Indonesia 	              Indonesia
nz    New Zealand 	              New Zealand
tw3   Taiwan 	                  Taiwan - 3
vn    Vietnam 	                  Vietnam
mo    Macau 	                  Macau
kh    Cambodia 	                  Cambodia
mn    Mongolia 	                  Mongolia
la    Laos 	                      Laos
mm    Myanmar 	                  Myanmar
np    Nepal 	                  Nepal
kg    Kyrgyzstan 	              Kyrgyzstan
uz    Uzbekistan 	              Uzbekistan
bd    Bangladesh 	              Bangladesh
bt    Bhutan 	                  Bhutan
bnbr  Brunei Darussalam 	      Brunei
cato  Canada 	                  Canada - Toronto
camo2                             Canada - Montreal - 2
cava                              Canada - Vancouver
cato2                             Canada - Toronto - 2
camo                              Canada - Montreal
mx    Mexico 	                  Mexico
br2   Brazil 	                  Brazil - 2
pa    Panama 	                  Panama
cl    Chile 	                  Chile
ar    Argentina 	              Argentina
cr    Costa Rica 	              Costa Rica
co    Colombia 	                  Colombia
ve    Venezuela 	              Venezuela
ec    Ecuador 	                  Ecuador
gt    Guatemala 	              Guatemala
pe    Peru 	                      Peru
uy    Uruguay 	                  Uruguay
bs    Bahamas 	                  Bahamas
ro    Romania 	                  Romania
im    Isle of Man 	              Isle of Man
esma  Spain 	                  Spain - Madrid
esba                              Spain - Barcelona
tr    Turkey 	                  Turkey
ie    Ireland                     Ireland
is    Iceland 	                  Iceland
no    Norway 	                  Norway
dk    Denmark 	                  Denmark
be    Belgium 	                  Belgium
fi    Finland 	                  Finland
gr    Greece 	                  Greece
pt    Portugal 	                  Portugal
at    Austria 	                  Austria
am    Armenia 	                  Armenia
pl    Poland 	                  Poland
lt    Lithuania 	              Lithuania
lv    Latvia 	                  Latvia
ee    Estonia 	                  Estonia
cz    Czech Republic 	          Czech Republic
ad    Andorra 	                  Andorra
me    Montenegro 	              Montenegro
ba    Bosnia and Herzegovina 	  Bosnia and Herzegovina
lu    Luxembourg 	              Luxembourg
hu    Hungary 	                  Hungary
bg    Bulgaria 	                  Bulgaria
by    Belarus 	                  Belarus
ua    Ukraine 	                  Ukraine
mt    Malta 	                  Malta
li    Liechtenstein 	          Liechtenstein
cy    Cyprus 	                  Cyprus
al    Albania 	                  Albania
hr    Croatia 	                  Croatia
si    Slovenia 	                  Slovenia
sk    Slovakia 	                  Slovakia
mc    Monaco 	                  Monaco
je    Jersey 	                  Jersey
mk    North Macedonia 	          North Macedonia
md    Moldova 	                  Moldova
rs    Serbia 	                  Serbia
ge    Georgia 	                  Georgia
az    Azerbaijan 	              Azerbaijan
za    South Africa 	              South Africa
il    Israel 	                  Israel
eg    Egypt 	                  Egypt
ke    Kenya 	                  Kenya
dz    Algeria 	                  Algeria
```
