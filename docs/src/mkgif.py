import sys
from PIL import Image
d,o=sys.argv[1],sys.argv[2]
W=1600
dur=[1000]*6+[1300,900]+[1200,1200]+[900,900]
frames=[]
for i in range(12):
    im=Image.open(f'{d}/frame-{i}.png').convert('RGB')
    im=im.resize((W,round(im.height*W/im.width)),Image.LANCZOS)
    frames.append(im)
# 所有帧共用一个调色板，避免闪烁
# 把各阶段的帧竖向拼起来统一取色，保证提示条黄色、红绿灯等都在调色板里
picks=[frames[i] for i in (0,2,4,6,8,10)]
sheet=Image.new('RGB',(W,sum(p.height for p in picks)))
y=0
for p in picks: sheet.paste(p,(0,y)); y+=p.height
pal=sheet.quantize(colors=255,method=Image.Quantize.FASTOCTREE,kmeans=2)
q=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
q[0].save(o,save_all=True,append_images=q[1:],duration=dur,loop=0,optimize=True,disposal=1)
for n in ['states','picker','menu','layout','keys','menus','agents','usage','files']:
    im=Image.open(f'{d}/{n}.png').convert('RGB'); im=im.resize((W,round(im.height*W/im.width)),Image.LANCZOS)
    im.save(f'{o.rsplit("/",1)[0]}/{n}.png',optimize=True)
