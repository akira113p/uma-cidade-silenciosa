import sys
from PIL import Image, ImageDraw
# folha.py saida.png colunas arq1 arq2 ...
saida, cols, *arqs = sys.argv[1:]
cols = int(cols); ims=[Image.open(a).convert("RGB") for a in arqs]
w,h = ims[0].size; rows=(len(ims)+cols-1)//cols
S = Image.new("RGB",(w*cols,h*rows))
for i,(im,a) in enumerate(zip(ims,arqs)):
    d=ImageDraw.Draw(im); d.text((6,6),a.split("/")[-1].replace(".png",""),fill=(255,255,0))
    S.paste(im,((i%cols)*w,(i//cols)*h))
S.save(saida)
