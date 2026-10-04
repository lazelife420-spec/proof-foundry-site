"""Bounded frozen-render comparator. See README.md for the complete contract."""
import json, re, itertools, hashlib, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
HERE=Path(__file__).resolve().parent
def load(p): return json.loads(Path(p).read_text(encoding='utf-8'))
def write(p,v): Path(p).write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
def png(p): return np.asarray(Image.open(p).convert('RGBA'))
def split_shadows(value):
    return re.split(r',\s*(?![^()]*\))',value)
def homography(w,h,quad):
    src=[(0,0),(w,0),(w,h),(0,h)]; dst=np.asarray(quad).reshape(4,2); a=[]; b=[]
    for (x,y),(u,v) in zip(src,dst):
        a.extend([[x,y,1,0,0,0,-u*x,-u*y],[0,0,0,x,y,1,-v*x,-v*y]]);b.extend([u,v])
    return np.append(np.linalg.solve(np.array(a),np.array(b)),1).reshape(3,3)
def envelope(receipt,size):
    """Project plate + actual outer-shadow support, then dilate one raster pixel.
    CSS box-shadow blur radius b -> sigma=b/2; 3sigma support=1.5b.
    For each non-inset shadow (dx,dy,b,s), local rect is
    [dx-s-1.5b,dy-s-1.5b,w+dx+s+1.5b,h+dy+s+1.5b].
    Map through the plate's CDP border-quad homography, convert viewport CSS
    to document CSS, then to screenshot pixels using clip/DPR and scroll.
    Subtract unrelated hero/navigation/proof-chain boxes plus one pixel.
    """
    imw,imh=size; element=receipt['elements']['.ledger-plate']; styles=element['styles']; w=float(styles['width'][:-2]);h=float(styles['height'][:-2])
    if styles['box-sizing']!='border-box': raise ValueError('Unsupported box sizing')
    q=np.asarray(receipt['boxModel']['border']).reshape(4,2); r=element['rect']
    # CDP reports CSS viewport coordinates; fail rather than silently guess a different coordinate basis.
    measured=[q[:,0].min(),q[:,1].min(),q[:,0].max()-q[:,0].min(),q[:,1].max()-q[:,1].min()]
    if max(abs(a-b) for a,b in zip(measured,[r['x'],r['y'],r['width'],r['height']]))>0.0002: raise ValueError('CDP/DOM coordinate mismatch')
    q=q+np.array([receipt['scrollX'],receipt['scrollY']]); H=homography(w,h,q)
    clip=receipt['captureParams'].get('clip'); scale=receipt['dpr']*(clip.get('scale',1) if clip else 1)
    origin=[clip['x'],clip['y']] if clip else [receipt['visualViewport']['pageLeft'],receipt['visualViewport']['pageTop']]
    rects=[{'kind':'plate','local':[0,0,w,h]}]; outer=[]
    for declaration in split_shadows(styles['box-shadow']):
        if 'inset' in declaration: continue
        lengths=[float(n) for n in re.findall(r'(-?[\d.]+)px',declaration)]
        if len(lengths) not in (2,3,4): raise ValueError('Unparsed outer shadow '+declaration)
        dx,dy=lengths[:2];blur=lengths[2] if len(lengths)>2 else 0;spread=lengths[3] if len(lengths)>3 else 0
        if blur<0: raise ValueError('Negative blur')
        support=1.5*blur
        row={'kind':'outer-shadow','declaration':declaration,'dx':dx,'dy':dy,'blur':blur,'spread':spread,'sigma':blur/2,'support':support,'local':[dx-spread-support,dy-spread-support,w+dx+spread+support,h+dy+spread+support]}
        rects.append(row);outer.append(row)
    if [(s['dx'],s['dy'],s['blur'],s['spread']) for s in outer]!=[(13,19,18,0),(3,4,2,0)]:raise ValueError('Frozen outer shadow changed')
    mask=Image.new('L',size,0);draw=ImageDraw.Draw(mask)
    for row in rects:
        x0,y0,x1,y1=row['local']; pts=[]
        for x,y in [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]:
            point=H@np.array([x,y,1]);point=point[:2]/point[2];point=(point-np.asarray(origin))*scale;pts.append(tuple(point))
        row['screenshotPolygon']=pts;draw.polygon(pts,fill=255)
    mask=mask.filter(ImageFilter.MaxFilter(3));draw=ImageDraw.Draw(mask)
    excluded=[]
    for box in receipt['exclusions']:
        x=(box['x']-origin[0])*scale;y=(box['y']-origin[1])*scale;bounds=[x-1,y-1,x+box['width']*scale+1,y+box['height']*scale+1];draw.rectangle(bounds,fill=0);excluded.append({'selector':box['selector'],'rasterBounds':bounds})
    allowed=np.asarray(mask)>0
    ys,xs=np.nonzero(allowed); bounds=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else None
    return allowed,{'plateBoundingRect':element['rect'],'plateDocumentRect':element['documentRect'],'localBorderBox':[w,h],'borderQuadDocumentCss':q.tolist(),'homography':H.tolist(),'originDocumentCss':origin,'rasterScale':scale,'shadowsAndPlate':rects,'antialiasAllowanceRasterPixels':1,'excludedUnrelatedBoxes':excluded,'envelopePixels':int(allowed.sum()),'rasterBounds':bounds,'coordinateBasis':'CDP border quad verified against DOM viewport CSS bounds'}
def guards(receipt):
    # Every requested element: exact geometry, styles, pseudo styles, attributes and DOM text; five source/asset hashes.
    return {k:receipt[k] for k in ['elements','boxModel','sourceHashes','captureParams','dpr','innerWidth','innerHeight','scrollX','scrollY','visualViewport','document','exclusions']}
def compare(a,b,mask):
    if a.shape!=b.shape:return {'pass':False,'reason':['DIMENSIONS'],'referenceDimensions':[a.shape[1],a.shape[0]],'actualDimensions':[b.shape[1],b.shape[0]]}
    delta=np.abs(a.astype(np.int16)-b.astype(np.int16));changed=delta.any(axis=2);ys,xs=np.nonzero(changed);outside=changed&~mask;excess=(delta[:,:,:3]>1).any(axis=2)&mask;alpha=delta[:,:,3]!=0;reasons=[]
    if outside.any():reasons.append('OUTSIDE_ENVELOPE_RGBA')
    if excess.any():reasons.append('INSIDE_ENVELOPE_RGB_GT_1')
    if alpha.any():reasons.append('ALPHA')
    return {'pass':not reasons,'reason':reasons,'dimensions':[a.shape[1],a.shape[0]],'pixels':int(changed.size),'changedPixels':int(changed.sum()),'changedPercentage':float(changed.mean()*100),'bounds':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else None,'maxRGBDelta':delta[:,:,:3].max(axis=(0,1)).tolist(),'maxAlphaDelta':int(delta[:,:,3].max()),'alphaChangedPixels':int(alpha.sum()),'changedOutsideEnvelope':int(outside.sum()),'insideExcessPixels':int(excess.sum()),'allChangedWithinEnvelope':not bool(outside.any()),'exactDeterministicPixelsChecked':int((~mask).sum()),'toleratedDecorativePixels':int((changed&mask&~alpha&~excess).sum())}

def diff_paths(a,b,p=''):
    if isinstance(a,dict) and isinstance(b,dict):
        output=[]
        for k in sorted(set(a)|set(b)):
            if k not in a or k not in b:output.append(p+'/'+k)
            else:output.extend(diff_paths(a[k],b[k],p+'/'+k))
        return output
    return [] if a==b else [p]

def main():
    if len(sys.argv)!=5:raise SystemExit('Usage: compare.py ROOT PRIMARY_CAPTURES GEOMETRY_CAPTURES OUTPUT_JSON')
    root,primary,geometry,output=map(Path,sys.argv[1:]);manifest=load(HERE/'manifest.json');frozen=load(HERE/'frozen-guards.json');rows=[];failures=[]
    current_hashes={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in manifest['sourceHashes']}
    hashes_exact=current_hashes==manifest['sourceHashes']
    for name,expected_sha in manifest['references'].items():
        reference=HERE/'references'/name
        if hashlib.sha256(reference.read_bytes()).hexdigest()!=expected_sha:raise RuntimeError('Frozen reference byte drift: '+name)
        receipt=load(geometry/(name+'.geometry.json'));expected=frozen[name];ref=png(reference)
        mask,detail=envelope(expected,(ref.shape[1],ref.shape[0]));guard_changes=diff_paths(guards(expected),guards(receipt))
        recorded_hashes_exact=receipt['sourceHashes']==manifest['sourceHashes']
        geometry_image=geometry/name;receipt_binding=receipt['pngSha256']==hashlib.sha256(geometry_image.read_bytes()).hexdigest()
        actual=compare(ref,png(primary/name),mask);auxiliary=compare(ref,png(geometry_image),mask)
        reasons=actual['reason'].copy()
        if guard_changes:reasons.append('EXACT_STRUCTURAL_GUARD')
        if not hashes_exact or not recorded_hashes_exact:reasons.append('FROZEN_SOURCE_ASSET_HASH')
        if not receipt_binding:reasons.append('GEOMETRY_RECEIPT_PNG_BINDING')
        if not auxiliary['pass']:reasons.append('GEOMETRY_CAPTURE_PIXEL_CONTRACT')
        row={'name':name,**actual,'pass':not reasons,'reason':reasons,'envelope':detail,'geometryStyleTextAttributesExact':not guard_changes,'guardChanges':guard_changes,'sourceAssetHashesExact':hashes_exact and recorded_hashes_exact,'geometryReceiptPNGExact':receipt_binding,'geometryCaptureComparison':auxiliary,'primaryPNG_SHA256':hashlib.sha256((primary/name).read_bytes()).hexdigest(),'referencePNG_SHA256':expected_sha}
        rows.append(row)
        if not row['pass']:failures.append(row)
    result={'contract':'PROOF_LEDGER_BOUNDED_DECORATIVE_PAINT','passed':sum(r['pass'] for r in rows),'total':len(rows),'failed':failures,'images':rows,'sourceHashes':current_hashes,'insideRGBDeltaMaximum':1,'outsideRGBAExact':True,'alphaExact':True,'referencesRegenerated':False,'physicalWindowsReducedMotion':'NOT TESTED'}
    if output.exists():raise RuntimeError('Refusing to overwrite a comparison attempt')
    write(output,result);print(json.dumps({'passed':result['passed'],'total':result['total'],'failed':len(failures),'maximumToleratedPixels':max(r.get('toleratedDecorativePixels',0) for r in rows)}))
    raise SystemExit(0 if not failures and len(rows)==8 else 1)
if __name__=='__main__':main()
