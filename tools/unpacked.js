// Lists files marked "unpacked" in an asar header. Usage: node unpacked.js <app.asar>
const asar=require('@electron/asar');
const h=asar.getRawHeader(process.argv[2]).header;const out=[];
(function walk(n,p){for(const[k,v]of Object.entries(n.files||{})){const q=p?p+'/'+k:k;if(v.files)walk(v,q);else if(v.unpacked)out.push(q)}})(h,'');
console.log(JSON.stringify(out));
