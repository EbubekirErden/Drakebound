#!/usr/bin/env python3
"""Convert pinned SRD-only Open5e metadata and SRD 5.2.1 Markdown into Drakebound references.
No user files are read. Run with --open5e, --markdown and --output directories.
"""
import argparse,json,re,uuid,html,hashlib,pathlib,collections
from html.parser import HTMLParser
class PlainHTML(HTMLParser):
 def __init__(self): super().__init__();self.out=[]
 def handle_starttag(self,t,a):
  if t in ['tr','p','br']:self.out.append('\n')
 def handle_endtag(self,t):
  if t in ['td','th']:self.out.append(' | ')
 def handle_data(self,s):self.out.append(s)
def clean(s):
 p=PlainHTML();p.feed(s);s=''.join(p.out)
 s=re.sub(r'\n[ \t]+','\n',s);s=re.sub(r'\n{3,}','\n\n',s)
 return html.unescape(s).strip()
def key(s):return re.sub(r'[^a-z0-9]','',s.lower())
def sections(text,level):
 hits=list(re.finditer(r'^'+('#'*level)+r' (.+)$',text,re.M));out={}
 for i,m in enumerate(hits):
  # Stop at the next heading at this level or above, retaining nested headings.
  end=re.search(r'^#{1,'+str(level)+r'} ',text[m.end():],re.M)
  out[key(m[1])]=(m[1],text[m.end():m.end()+end.start()] if end else text[m.end():])
 return out
def field(n,t='',children=None,attrs=None):return dict(name=n,text=str(t),attributes=attrs or {},children=children or [])
def trait(n,t,attrs=None):return field('trait',children=[field('name',n),field('text',clean(t))],attrs=attrs)
def load(n):return json.loads((source/(n+'.json')).read_text())
def grouped(n,k='parent'):
 d=collections.defaultdict(list)
 for x in load(n):d[x['fields'][k]].append(x)
 return d
ap=argparse.ArgumentParser();ap.add_argument('--open5e',required=True);ap.add_argument('--markdown',required=True);ap.add_argument('--output',required=True);args=ap.parse_args()
source=pathlib.Path(args.open5e);md=pathlib.Path(args.markdown);dest=pathlib.Path(args.output);dest.mkdir(parents=True,exist_ok=True)
entries=[];namespace=uuid.UUID('5182ee73-d6de-4793-8cf7-f8b9fc59a47f')
notice='SRD 5.2 / 5.2.1 (2024) · CC BY 4.0'
def entry(cat,pk,name,fields):
 name=name+' [2024]'; entries.append(dict(id=str(uuid.uuid5(namespace,cat+":"+pk)).upper(),category=cat,name=name,fields=[field('name',name)]+fields+[field('source',notice),field('attribution','This work includes material from the System Reference Document 5.2 (“SRD 5.2”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode. This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode. Descriptions reformatted; structured metadata adapted from Open5e.')],custom=False))
spells=sections((md/'spells.md').read_text(encoding='utf-8-sig'),4)
classes={x['pk']:x['fields'] for x in load('CharacterClass')}
opts=grouped('SpellCastingOption')
for x in load('Spell'):
 f=x['fields'];name=f['name'];_,body=spells[key(name)];body=body.replace('**Component:**','**Components:**')
 assert all(re.search(r'\*\*'+k+r':\*\* (.+)',body) for k in ['Casting Time','Range','Components','Duration']), (name,body[:1200])
 metadata={k:re.search(r'\*\*'+k+r':\*\* (.+)',body).group(1).strip() for k in ['Casting Time','Range','Components','Duration']}
 header=body.strip().splitlines()[0];level=int(re.search(r'Level (\d)',header)[1]) if 'Cantrip' not in header else 0
 assert level==f['level'],name
 desc=body[re.search(r'\*\*Duration:\*\*[^\n]*',body).end():].strip()
 fs=[field('level',level),field('school',f['school'].title()),field('time',metadata['Casting Time'].replace(' or Ritual','')),field('range',metadata['Range']),field('components',metadata['Components']),field('duration',metadata['Duration']),field('concentration','YES' if 'Concentration' in metadata['Duration'] else 'NO'),field('ritual',int('Ritual' in metadata['Casting Time'])),field('classes',', '.join(classes[c]['name'] for c in f['classes'])),field('text',clean(desc))]
 damage=f.get('damage_roll') or ''
 # Only expose syntactically valid dice explicitly present in the reference. No guessed roll-on-cast effects.
 if re.fullmatch(r'\d+d\d+(?:\s*[+−-]\s*\d+)?',damage) and damage.replace(' ','') in desc.replace(' ',''):
  variants={o['fields']['type']:o['fields']['damage_roll'] for o in opts[x['pk']]}
  keys=['slot_level_'+str(i) for i in range(level+1,10)] if level else ['player_level_'+str(i) for i in [5,11,17]]
  rolls=[damage]+[variants[k] for k in keys] if keys and all(variants.get(k) and re.fullmatch(r'\d+d\d+(?:\s*[+−-]\s*\d+)?',variants[k]) for k in keys) else [damage]
  fs += [field('roll',r.replace('−','-').replace(' ','')) for r in rolls]
 entry('Spells',x['pk'],name,fs)
# Class feature text comes from the 5.2.1 reference; Open5e contributes progression-table metadata.
classblocks=sections((md/'classes.md').read_text(encoding='utf-8-sig'),2)
features=grouped('ClassFeature');featureitems=grouped('ClassFeatureItem')
ability={'str':'Strength','dex':'Dexterity','con':'Constitution','int':'Intelligence','wis':'Wisdom','cha':'Charisma'}
casting={'Bard':'Charisma','Cleric':'Wisdom','Druid':'Wisdom','Paladin':'Charisma','Ranger':'Wisdom','Sorcerer':'Charisma','Warlock':'Charisma','Wizard':'Intelligence'}
for pk,f in classes.items():
 if f['subclass_of']:continue
 name=f['name'];_,body=classblocks[key(name)];children=collections.defaultdict(list);cols=collections.defaultdict(dict)
 # Match feature levels and keep the subclass context explicit.
 heads=list(re.finditer(r'^(#{3,4}) (.+)$',body,re.M));sub=None
 for i,m in enumerate(heads):
  title=m[2]
  if len(m[1])==3:
   sub=title.split('Subclass: ',1)[1] if 'Subclass: ' in title else None
   if sub:children[3].append(field('feature',attrs={'optional':'YES','subclass':sub},children=[field('name','Subclass: '+sub),field('text',clean(body[m.end():heads[i+1].start()] if i+1<len(heads) else body[m.end():]))]))
  match=re.match(r'Level (\d+): (.+)',title)
  if not match:continue
  level=int(match[1]);title=match[2];end=heads[i+1].start() if i+1<len(heads) else len(body)
  children[level].append(field('feature',attrs={'optional':'YES','subclass':sub} if sub else {},children=[field('name',title),field('text',clean(body[m.end():end]))]))
 # ASI repetitions and slots/cantrips are explicitly listed in the source table.
 for feat in features[pk]:
  for fi in featureitems[feat['pk']]:
   g=fi['fields'];level=g['level'];title=feat['fields']['name']
   if g['column_value'] is not None:cols[level][title]=g['column_value']
   if title=='Ability Score Improvement' and not any(z['children'][0]['text']==title for z in children[level]):
    original=next((z for zs in children.values() for z in zs if z['children'][0]['text']==title),None)
    if original:children[level].append(original.copy())
 fs=[field('hd',f['hit_dice'][1:]),field('proficiency',', '.join(ability[a]+' Saving Throws' for a in f['saving_throws'])),field('spellAbility',casting.get(name,'')),field('text',clean(body[:body.find('### ')]))]
 # Skills are chosen using the exact starting-traits list.
 core=body[:body.find('### ')]
 skillrow=re.search(r'<tr>\s*<td>Skill Proficiencies</td>\s*<td>(.*?)</td>',core,re.S)
 skills=re.search(r'(.+)',clean(skillrow[1])) if skillrow else None
 if skills:
  text=skills[1].strip('| '); choices=re.search(r'Choose (?:any )?(\d+)',text)
  fs.append(field('numSkills',choices[1] if choices else '2'))
  available=re.sub(r'^Choose \d+:?\s*','',text).replace(', or ', ', ').replace(' or ',', ')
  fs[1]['text']+=', '+available
 saves=re.search(r'<tr>\s*<td>Saving Throw Proficiencies</td>\s*<td>(.*?)</td>',core,re.S)
 assert saves,name
 source_saves=[a+' Saving Throws' for a in ability.values() if a in clean(saves[1])]
 fs[1]['text']=', '.join(source_saves)+(', '+available if skills else '')
 for level in range(1,21):
  c=cols[level]
  cantrips=c.get('Cantrips',c.get('Cantrips Known','0'))
  ords=['1st','2nd','3rd','4th','5th','6th','7th','8th','9th']
  slots=[c.get(o,'0') for o in ords]
  if name=='Warlock':
   count=c.get('Spell Slots','0');sl=c.get('Slot Level','0');sl=int(re.sub(r'\D','',sl) or 0)
   slots=[count if i==sl else '0' for i in range(1,10)]
  if name in casting:children[level].append(field('slots',','.join([str(cantrips)]+[str(s) if str(s).isdigit() else '0' for s in slots])))
  if children[level]:fs.append(field('autolevel',attrs={'level':str(level)},children=children[level]))
 if name=='Warlock':fs.append(field('slotsReset','S'))
 entry('Classes',pk,name,fs)
origins=sections((md/'character-origins.md').read_text(),4)
traits=grouped('SpeciesTrait');benefits=grouped('BackgroundBenefit')
for x in load('Species'):
 f=x['fields'];_,body=origins[key(f['name'])];fs=[]
 speed=re.search(r'\*\*Speed:\*\* (\d+)',body);size=re.search(r'\*\*Size:\*\* ([^\n]+)',body)
 fs+=[field('speed',speed[1] if speed else '30'),field('size',size[1] if size else 'Medium')]
 # Preserve tables and lineage choices together; nothing is dropped or guessed into automated bonuses.
 fs.append(trait(f['name']+' traits',body))
 entry('Races',x['pk'],f['name'],fs)
for x in load('Background'):
 f=x['fields'];_,body=origins[key(f['name'])];fs=[]
 for b in benefits[x['pk']]:
  g=b['fields']
  if g['type']=='ability_score':fs.append(field('ability',g['desc']))
  elif g['type']=='skill_proficiency':fs.append(field('proficiency',g['desc'].replace(' and ',', ')))
 fs.append(trait(f['name'],body));entry('Backgrounds',x['pk'],f['name'],fs)
feats=sections((md/'feats.md').read_text(),4)
for x in load('Feat'):
 f=x['fields'];_,body=feats[key(f['name'])]
 entry('Feats',x['pk'],f['name'],[field('prerequisite',f['prerequisite']),field('text',clean(body))])
weapons={x['pk']:x['fields'] for x in load('Weapon')};armors={x['pk']:x['fields'] for x in load('Armor')};props=grouped('WeaponPropertyAssignment','weapon');propnames={x['pk']:x['fields']['name'] for x in load('WeaponProperty')}
for kind in ['Item','MagicItem']:
 for x in load(kind):
  f=x['fields'];w=weapons.get(f['weapon']);a=armors.get(f['armor']);cat=f['category'];code='G'
  if kind=='MagicItem':code={'potion':'P','ring':'RG','rod':'RD','staff':'ST','wand':'WD','scroll':'SC'}.get(cat,'W')
  if w:code='R' if w['range'] else 'M'
  if a:code='S' if f['name']=='Shield' else 'HA' if not a['ac_add_dexmod'] else 'MA' if a['ac_cap_dexmod']==2 else 'LA'
  fs=[field('type',code),field('weight',f['weight']),field('detail',cat),field('text',f['desc']),field('value',f['cost'])]
  if w:
   codes={'Finesse':'F','Light':'L','Heavy':'H','Two-Handed':'2H','Reach':'R','Thrown':'T','Loading':'LD','Ammunition':'A','Versatile':'V'}
   ps=[propnames[z['fields']['property']] for z in props[f['weapon']]]
   fs +=[field('dmg1',w['damage_dice']),field('dmgType',w['damage_type'].title()),field('property',', '.join(codes.get(p,p) for p in ps)),field('text','Proficiency: '+('simple' if w['is_simple'] else 'martial')+', '+w['name']),field('range',str(w['range'])+('/'+str(w['long_range']) if w['long_range'] else '') if w['range'] else '')]
  if a:fs.append(field('ac',a['ac_base']))
  if kind=='MagicItem':fs +=[field('rarity',f['rarity']),field('attunement',str(f['requires_attunement']))]
  entry('Equipment',kind+':'+x['pk'],f['name'],fs)
actions=grouped('CreatureAction');attacks=grouped('CreatureActionAttack');traits=grouped('CreatureTrait')
for x in load('Creature'):
 f=x['fields'];fs=[field('hp',f['hit_points']),field('ac',f['armor_class']),field('size',f['size'].title()),field('type',f['type']),field('cr',str(float(f['challenge_rating'])).rstrip('0').rstrip('.')),field('speed',', '.join((('' if k=='walk' else k.title()+' ')+str(f[k])+' ft.') for k in ['walk','fly','swim','climb','burrow'] if f[k])),field('languages',f['languages_desc']),field('alignment',f['alignment'])]
 for a,b in ability.items():fs.append(field(a,f['ability_score_'+b.lower()]))
 for k in ['damage_immunities','damage_resistances','damage_vulnerabilities','condition_immunities']:
  if f[k]:fs.append(field(k,', '.join(f[k])))
 for tr in traits[x['pk']]:fs.append(trait(tr['fields']['name'],tr['fields']['desc']))
 for ac in actions[x['pk']]:
  g=ac['fields'];cs=[field('name',g['name']),field('text',g['desc'])]
  for at in attacks[ac['pk']]:
   h=at['fields'];die=h['damage_die_type'];count=h['damage_die_count'];bonus=h['damage_bonus'] or 0
   if die and count and h['to_hit_mod'] is not None:cs.append(field('attack',g['name']+'|'+str(h['to_hit_mod'])+'|'+str(count)+die.lower()+(('+' if bonus>0 else '')+str(bonus) if bonus else '')))
  tag={'REACTION':'reaction','LEGENDARY_ACTION':'legendary','BONUS_ACTION':'trait'}.get(g['action_type'],'action')
  fs.append(field(tag,children=cs))
 entry('Creatures',x['pk'],f['name'],fs)
ids=[e['id'] for e in entries];assert len(ids)==len(set(ids))
(dest/'srd-compendium.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
print(dict(collections.Counter(e['category'] for e in entries)))
