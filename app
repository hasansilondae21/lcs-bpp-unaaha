/* ══════════════════════════════════════════════
   LCS Screenshot BPP Unaaha — app.js
   Host: GitHub Pages
   Backend: Google Apps Script
══════════════════════════════════════════════ */

// ── GANTI URL INI dengan URL deployment Apps Script Anda ──
var GAS_URL = 'GANTI_DENGAN_URL_DEPLOYMENT_APPS_SCRIPT';

// ══ STATE ══════════════════════════════════════
var PENYULUH     = [];
var rekapData    = [];
var pendingB64   = null;
var pendingMime  = '';
var pendingFName = '';
var adminPin     = '';
var hapusTargetUid = '';
var adminDataCache = [];

// ══ GAS REQUEST (JSONP) ════════════════════════
function gasCall(action, params, onSuccess, onError) {
  var callbackName = 'cb_' + Date.now() + '_' + Math.floor(Math.random()*9999);
  var url = GAS_URL + '?action=' + encodeURIComponent(action)
    + '&callback=' + callbackName;
  if (params) url += '&data=' + encodeURIComponent(JSON.stringify(params));

  window[callbackName] = function(res) {
    delete window[callbackName];
    document.head.removeChild(script);
    clearTimeout(timer);
    onSuccess(res);
  };

  var timer = setTimeout(function() {
    delete window[callbackName];
    if (document.head.contains(script)) document.head.removeChild(script);
    if (onError) onError({message:'Timeout — periksa koneksi internet'});
  }, 30000);

  var script = document.createElement('script');
  script.src = url;
  script.onerror = function() {
    delete window[callbackName];
    clearTimeout(timer);
    if (onError) onError({message:'Gagal menghubungi server'});
  };
  document.head.appendChild(script);
}

// ══ INIT ═══════════════════════════════════════
document.addEventListener('DOMContentLoaded', function() {
  gasCall('getDaftarPenyuluh', null, function(list) {
    PENYULUH = list;
    isiSelect('sel-nama', list, '— Pilih nama Anda —');
    isiSelect('f-nama',   list, 'Semua Penyuluh');
    muatStatus();
  }, function(e) { toast('Gagal memuat data: '+e.message, 'er'); });
});

function isiSelect(id, list, placeholder) {
  var sel = document.getElementById(id);
  sel.innerHTML = '<option value="">'+placeholder+'</option>';
  list.forEach(function(n) {
    var o = document.createElement('option');
    o.value = n; o.textContent = n;
    sel.appendChild(o);
  });
}

// ══ TAB SWITCH ═════════════════════════════════
function switchTab(name, el) {
  document.querySelectorAll('.tab').forEach(function(t){t.classList.remove('active')});
  document.querySelectorAll('.view').forEach(function(v){v.classList.remove('active')});
  el.classList.add('active');
  document.getElementById('view-'+name).classList.add('active');
  var fw = document.getElementById('float-wrap');
  fw.style.display = name === 'input' ? '' : 'none';
  if (name === 'rekap') muatDaftarTanggalLaluRekap();
}

// ══ TANGGAL ════════════════════════════════════
function tanggalHariIni() {
  var now = new Date();
  return String(now.getDate()).padStart(2,'0')+'/'+
         String(now.getMonth()+1).padStart(2,'0')+'/'+
         now.getFullYear();
}

function muatDaftarTanggalLaluRekap() {
  gasCall('getDaftarTanggal', null, function(res) {
    if (!res.ok) { muatRekap(); return; }
    var sel = document.getElementById('f-tgl');
    sel.innerHTML = '<option value="">Semua Tanggal</option>';
    res.data.forEach(function(tgl) {
      var o = document.createElement('option');
      o.value = tgl; o.textContent = tgl; sel.appendChild(o);
    });
    var hi = tanggalHariIni();
    sel.value = res.data.indexOf(hi) !== -1 ? hi : '';
    muatRekap();
  }, function() { muatRekap(); });
}

// ══ FILE INPUT ═════════════════════════════════
var dz = null;
document.addEventListener('DOMContentLoaded', function() {
  dz = document.getElementById('dz');
  document.getElementById('inp-file').addEventListener('change', function() {
    if (this.files[0]) bacaFile(this.files[0]);
  });
  dz.addEventListener('dragover', function(e){e.preventDefault();dz.classList.add('over')});
  dz.addEventListener('dragleave', function(){dz.classList.remove('over')});
  dz.addEventListener('drop', function(e){
    e.preventDefault(); dz.classList.remove('over');
    var f = e.dataTransfer.files[0];
    if (f && f.type.startsWith('image/')) bacaFile(f);
  });
  document.addEventListener('paste', function(e){
    var items = e.clipboardData && e.clipboardData.items;
    if (!items) return;
    for (var i=0;i<items.length;i++){
      if (items[i].type.startsWith('image/')){bacaFile(items[i].getAsFile());break}
    }
  });
});

function bacaFile(file) {
  var reader = new FileReader();
  reader.onload = function(e) {
    var img = new Image();
    img.onload = function() {
      var MAKS=1280, Q=0.75;
      var sk = Math.min(MAKS/img.width, MAKS/img.height, 1);
      var w  = Math.round(img.width*sk), h = Math.round(img.height*sk);
      var c  = document.createElement('canvas');
      c.width=w; c.height=h;
      c.getContext('2d').drawImage(img,0,0,w,h);
      var du = c.toDataURL('image/jpeg', Q);
      pendingB64   = du.split(',')[1];
      pendingMime  = 'image/jpeg';
      pendingFName = file.name ? file.name.replace(/\.[^.]+$/,'')+'.jpg' : 'screenshot_'+Date.now()+'.jpg';
      document.getElementById('dz-prev').src = du;
      document.getElementById('dz-name').textContent = pendingFName;
      dz.classList.add('has');
    };
    img.src = e.target.result;
  };
  reader.readAsDataURL(file);
}

// ══ KIRIM DATA ═════════════════════════════════
function kirimData() {
  var nama = document.getElementById('sel-nama').value;
  if (!nama)       { toast('Pilih nama terlebih dahulu!','er'); return; }
  if (!pendingB64) { toast('Screenshot belum dipilih!','er');   return; }
  overlay(true,'Mengunggah screenshot...');
  gasCall('simpanData',
    {nama:nama, base64:pendingB64, mimeType:pendingMime, fileName:pendingFName},
    function(res) {
      overlay(false);
      if (res.ok) {
        toast('✓ Screenshot '+nama+' berhasil disimpan','ok');
        resetInput(); muatStatus();
      } else { toast('Gagal: '+res.error,'er'); }
    },
    function(e){ overlay(false); toast('Error: '+e.message,'er'); }
  );
}

function resetInput() {
  document.getElementById('sel-nama').value = '';
  document.getElementById('inp-file').value = '';
  pendingB64=null; pendingMime=''; pendingFName='';
  document.getElementById('dz-prev').src = '';
  document.getElementById('dz-name').textContent = '';
  dz.classList.remove('has');
}

// ══ STATUS HARI INI ════════════════════════════
function muatStatus() {
  gasCall('getStatusHariIni', null, renderStatus,
    function(e){ toast('Gagal muat status: '+e.message,'er'); });
}

function renderStatus(res) {
  if (!res.ok) { toast('Error: '+res.error,'er'); return; }
  document.getElementById('status-title').textContent = 'Status Input — '+res.tanggal;
  var sudah = res.status.filter(function(s){return s.sudah}).length;
  var grid  = document.getElementById('status-grid');
  grid.innerHTML = '';
  res.status.forEach(function(s){
    var d = document.createElement('div');
    d.className = 'status-pill '+(s.sudah?'done':'pending');
    d.innerHTML = '<div class="s-dot"></div>'
      +'<div class="s-name">'+esc(s.nama)+'</div>'
      +(s.sudah?'<div class="s-ck">✓</div>':'');
    grid.appendChild(d);
  });
  var info = document.createElement('div');
  info.className = 'status-info';
  info.textContent = sudah+' dari '+res.status.length+' penyuluh sudah input hari ini.';
  grid.appendChild(info);
}

// ══ REKAP ══════════════════════════════════════
function muatRekap() {
  var filter = {
    nama   : document.getElementById('f-nama').value,
    tanggal: document.getElementById('f-tgl').value
  };
  overlay(true,'Memuat data rekap...');
  gasCall('getAllData', filter, function(res){
    overlay(false);
    if (!res.ok){ toast('Error: '+res.error,'er'); return; }
    rekapData = res.data;
    renderRekap(res.data);
  }, function(e){ overlay(false); toast('Error: '+e.message,'er'); });
}

function resetFilter() {
  document.getElementById('f-nama').value = '';
  document.getElementById('f-tgl').value  = '';
  muatRekap();
}

function renderRekap(data) {
  var div   = document.getElementById('rekap-body');
  var btn   = document.getElementById('btn-pdf');
  var btnDl = document.getElementById('btn-dl-semua');
  if (!data.length) {
    div.innerHTML = '<div class="empty"><div class="empty-icon">📭</div>Tidak ada data untuk filter ini.</div>';
    btn.disabled=true; btnDl.style.display='none'; return;
  }
  btn.disabled = false;
  btnDl.style.display = document.getElementById('f-nama').value ? 'flex' : 'none';
  var html = '<div class="tbl-wrap"><table>'
    +'<thead><tr><th>#</th><th>Nama</th><th>Tanggal</th><th>Foto</th></tr></thead><tbody>';
  data.forEach(function(r,i){
    html += '<tr>'
      +'<td>'+( i+1)+'</td>'
      +'<td><strong>'+esc(r.nama)+'</strong></td>'
      +'<td>'+esc(r.tanggal)+'</td>'
      +'<td><div class="td-aksi">'
      +'<button class="btn btn-outline btn-sm" onclick="lihatFoto('+i+')">🖼 Lihat</button>'
      +'<button class="btn btn-outline btn-sm" onclick="downloadFoto('+i+')">⬇ Unduh</button>'
      +'</div></td>'
      +'</tr>';
  });
  html += '</tbody></table></div>';
  div.innerHTML = html;
}

// ══ MODAL FOTO ═════════════════════════════════
function lihatFoto(idx) {
  var r = rekapData[idx]; if (!r) return;
  document.getElementById('modal-judul').textContent = r.nama;
  document.getElementById('modal-sub').textContent   = r.tanggal+' · '+r.waktu;
  document.getElementById('modal-img').style.display    = 'none';
  document.getElementById('modal-error').style.display  = 'none';
  document.getElementById('modal-loading').style.display = 'block';
  document.getElementById('modal-bg').classList.add('on');
  document.body.style.overflow = 'hidden';
  gasCall('getImageBase64', {url:r.url}, function(res){
    document.getElementById('modal-loading').style.display = 'none';
    if (res.ok) {
      var img = document.getElementById('modal-img');
      img.src = 'data:'+res.mime+';base64,'+res.base64;
      img.style.display = 'block';
    } else { document.getElementById('modal-error').style.display='block'; }
  }, function(){
    document.getElementById('modal-loading').style.display='none';
    document.getElementById('modal-error').style.display='block';
  });
}

function tutupModal(e) {
  if (e && e.target !== document.getElementById('modal-bg')) return;
  document.getElementById('modal-bg').classList.remove('on');
  document.getElementById('modal-img').src = '';
  document.body.style.overflow = '';
}
document.addEventListener('keydown', function(e){ if(e.key==='Escape') tutupModal(null); });

// ══ DOWNLOAD PDF ═══════════════════════════════
function downloadPDF() {
  if (!rekapData.length) { toast('Tidak ada data','er'); return; }
  overlay(true,'Memuat gambar untuk PDF...');
  document.getElementById('btn-pdf').disabled = true;
  var pending = rekapData.map(function(r){return {item:r,b64:null,mime:null};});
  function muatGambar(idx) {
    if (idx >= pending.length) {
      bangunPrintPages(pending);
      overlay(false);
      document.getElementById('btn-pdf').disabled = false;
      setTimeout(function(){ window.print(); }, 200);
      return;
    }
    document.getElementById('ov-msg').textContent = 'Memuat gambar '+(idx+1)+' dari '+pending.length+'...';
    gasCall('getImageBase64', {url:pending[idx].item.url}, function(res){
      if(res.ok){pending[idx].b64=res.base64;pending[idx].mime=res.mime;}
      muatGambar(idx+1);
    }, function(){ muatGambar(idx+1); });
  }
  muatGambar(0);
}

function bangunPrintPages(items) {
  var tgl = new Date().toLocaleDateString('id-ID',{day:'2-digit',month:'long',year:'numeric'});
  var pp  = document.getElementById('print-pages');
  pp.innerHTML = '';
  items.forEach(function(p,i){
    var imgTag = p.b64
      ? '<img class="pimg" src="data:'+p.mime+';base64,'+p.b64+'"/>'
      : '<div style="padding:40px;text-align:center;color:#aaa;border:1px dashed #ccc;border-radius:6px">Gambar tidak tersedia</div>';
    var pg = document.createElement('div');
    pg.className = 'print-page';
    pg.innerHTML =
      '<div class="pkop"><div class="pkop-icon">🌾</div>'
      +'<div><h2>Rekap LCS Screenshot — BPP Unaaha</h2>'
      +'<p>Kabupaten Konawe &nbsp;|&nbsp; Dicetak: '+tgl+'</p></div></div>'
      +'<div class="pname">'+esc(p.item.nama)+'</div>'
      +'<div class="pmeta">'+esc(p.item.tanggal)+' · '+esc(p.item.waktu)+'</div>'
      +'<div class="pimg-wrap">'+imgTag+'</div>'
      +'<div class="pfooter">Halaman '+(i+1)+' dari '+items.length+'</div>';
    pp.appendChild(pg);
  });
}

// ══ DOWNLOAD FOTO ══════════════════════════════
function downloadFoto(idx) {
  var r = rekapData[idx]; if (!r) return;
  dlProgress('Mengunduh foto...');
  gasCall('getImageBase64', {url:r.url}, function(res){
    sembunyiDl();
    if (!res.ok){ toast('Gagal mengunduh','er'); return; }
    var a = document.createElement('a');
    a.href = 'data:'+res.mime+';base64,'+res.base64;
    a.download = r.nama.replace(/[^a-zA-Z0-9]/g,'_')+'_'+r.tanggal.replace(/\//g,'-')+'.jpg';
    document.body.appendChild(a); a.click(); document.body.removeChild(a);
    toast('✓ Foto berhasil diunduh','ok');
  }, function(e){ sembunyiDl(); toast('Error: '+e.message,'er'); });
}

function downloadSemuaFoto() {
  if (!rekapData.length){ toast('Tidak ada data','er'); return; }
  var nama = document.getElementById('f-nama').value;
  if (!nama){ toast('Pilih nama penyuluh terlebih dahulu','er'); return; }
  var total=rekapData.length, idx=0;
  function next() {
    if (idx>=total){ sembunyiDl(); toast('✓ Semua '+total+' foto diunduh','ok'); return; }
    var r=rekapData[idx];
    dlProgress('Mengunduh foto '+(idx+1)+' dari '+total+' — '+r.tanggal);
    gasCall('getImageBase64',{url:r.url},function(res){
      if(res.ok){
        var a=document.createElement('a');
        a.href='data:'+res.mime+';base64,'+res.base64;
        a.download=r.nama.replace(/[^a-zA-Z0-9]/g,'_')+'_'+r.tanggal.replace(/\//g,'-')+'_'+(idx+1)+'.jpg';
        document.body.appendChild(a);a.click();document.body.removeChild(a);
      }
      idx++; setTimeout(next,800);
    },function(){ idx++; setTimeout(next,800); });
  }
  next();
}

// ══ ADMIN ══════════════════════════════════════
function aksesAdmin() {
  var pin = document.getElementById('inp-pin').value;
  if (pin !== '2026') { document.getElementById('pin-error').style.display='block'; return; }
  adminPin = pin;
  document.getElementById('pin-error').style.display  = 'none';
  document.getElementById('admin-panel').style.display = 'block';
  isiSelect('af-nama', PENYULUH, 'Semua Penyuluh');
  muatTanggalAdmin();
  muatAdmin();
}

function muatTanggalAdmin() {
  gasCall('getDaftarTanggal', null, function(res){
    if (!res.ok) return;
    var sel = document.getElementById('af-tgl-sel');
    sel.innerHTML = '<option value="">Semua Tanggal</option>';
    res.data.forEach(function(tgl){
      var o=document.createElement('option');
      o.value=tgl;o.textContent=tgl;sel.appendChild(o);
    });
    var hi=tanggalHariIni();
    if(res.data.indexOf(hi)!==-1) sel.value=hi;
  }, null);
}

function muatAdmin() {
  var filter={
    nama   :document.getElementById('af-nama').value,
    tanggal:document.getElementById('af-tgl-sel').value
  };
  overlay(true,'Memuat data admin...');
  gasCall('getAllData', filter, function(res){
    overlay(false);
    if (!res.ok){ toast('Error: '+res.error,'er'); return; }
    adminDataCache=res.data; renderAdmin(res.data);
  }, function(e){ overlay(false); toast('Error: '+e.message,'er'); });
}

function resetAdmin(){
  document.getElementById('af-nama').value='';
  document.getElementById('af-tgl-sel').value='';
  muatAdmin();
}

function renderAdmin(data) {
  var div=document.getElementById('admin-body');
  if (!data.length){
    div.innerHTML='<div class="empty"><div class="empty-icon">📭</div>Tidak ada data.</div>';
    return;
  }
  var html='<div class="tbl-wrap"><table>'
    +'<thead><tr><th>#</th><th>Nama</th><th>Tanggal</th><th>Hapus</th></tr></thead><tbody>';
  data.forEach(function(r,i){
    html+='<tr>'
      +'<td>'+(i+1)+'</td>'
      +'<td><strong>'+esc(r.nama)+'</strong></td>'
      +'<td>'+esc(r.tanggal)+'</td>'
      +'<td><button class="btn btn-sm" style="background:#fdf2f1;color:var(--er);border:1.5px solid #f5c6c2" '
      +'onclick="konfirmasiHapus(\''+r.id+'\',\''+esc(r.nama)+'\',\''+esc(r.tanggal)+'\')">🗑 Hapus</button></td>'
      +'</tr>';
  });
  html+='</tbody></table></div>';
  div.innerHTML=html;
}

function konfirmasiHapus(uid,nama,tgl){
  hapusTargetUid=uid;
  document.getElementById('konfirm-nama').textContent=nama;
  document.getElementById('konfirm-tgl').textContent=tgl;
  document.getElementById('konfirm-bg').classList.add('on');
  document.body.style.overflow='hidden';
}
function batalHapus(){
  document.getElementById('konfirm-bg').classList.remove('on');
  document.body.style.overflow='';
}
function eksekusiHapus(){
  batalHapus();
  overlay(true,'Menghapus data...');
  gasCall('hapusDataAdmin',{uid:hapusTargetUid,pin:adminPin},function(res){
    overlay(false);
    if(res.ok){ toast('✓ Data berhasil dihapus','ok'); muatAdmin(); muatStatus(); }
    else toast('Gagal: '+res.error,'er');
  },function(e){ overlay(false); toast('Error: '+e.message,'er'); });
}

// ══ HELPERS ════════════════════════════════════
function overlay(on,msg){
  document.getElementById('overlay').classList.toggle('on',on);
  if(msg) document.getElementById('ov-msg').textContent=msg;
}
function toast(msg,type){
  var t=document.getElementById('toast');
  t.textContent=msg; t.className='show '+(type||'ok');
  clearTimeout(t._tid);
  t._tid=setTimeout(function(){t.className='';},3000);
}
function dlProgress(msg){
  var el=document.getElementById('dl-progress');
  el.textContent=msg; el.style.display='block';
}
function sembunyiDl(){
  document.getElementById('dl-progress').style.display='none';
}
function esc(s){
  return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
