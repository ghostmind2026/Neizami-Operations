<?php
/**
 * Plugin Name: Neizami Mobile Bridge - Voice Forms
 * Description: Voice trigger mappings for Neizami Operations Formidable forms.
 * Version: 1.0.0
 */
if (!defined('ABSPATH')) exit;

final class NZ_Mobile_Voice_Forms {
    const OPT = 'nz_mobile_voice_forms';

    public static function boot() {
        add_action('rest_api_init', [__CLASS__, 'rest']);
        add_action('admin_menu', [__CLASS__, 'menu'], 50);
        add_action('admin_post_nz_mobile_voice_save', [__CLASS__, 'save']);
    }

    public static function rest() {
        register_rest_route('neizami-mobile/v1', '/voice/commands', [
            'methods' => 'GET',
            'callback' => [__CLASS__, 'commands'],
            'permission_callback' => function () { return is_user_logged_in() || current_user_can('read'); },
        ]);
    }

    public static function commands() {
        $forms = get_option(self::OPT, []);
        return rest_ensure_response(['forms' => is_array($forms) ? array_values($forms) : []]);
    }

    public static function menu() {
        add_submenu_page('neizami-mobile-bridge', 'Voice Forms', 'Voice Forms', 'manage_options',
            'neizami-mobile-voice', [__CLASS__, 'page']);
    }

    private static function words($v) {
        if (is_string($v)) $v = preg_split('/[\r\n,،]+/u', $v);
        if (!is_array($v)) return [];
        return array_values(array_filter(array_unique(array_map(function($x){
            return trim(sanitize_text_field($x));
        }, $v))));
    }

    public static function save() {
        if (!current_user_can('manage_options')) wp_die('Forbidden');
        check_admin_referer('nz_mobile_voice_save');
        $raw = wp_unslash($_POST['voice_maps_json'] ?? '[]');
        $maps = json_decode($raw, true);
        if (!is_array($maps)) $maps = [];
        $clean = [];
        foreach ($maps as $m) {
            if (!is_array($m)) continue;
            $fk = sanitize_key($m['form_key'] ?? '');
            if (!$fk) continue;
            $fields = [];
            foreach (($m['fields'] ?? []) as $f) {
                if (!is_array($f)) continue;
                $key = sanitize_key($f['field_key'] ?? '');
                if (!$key) continue;
                $fields[] = ['field_key'=>$key,'label'=>sanitize_text_field($f['label'] ?? ''),
                    'triggers'=>self::words($f['triggers'] ?? [])];
            }
            $clean[] = ['form_key'=>$fk,'label'=>sanitize_text_field($m['label'] ?? ''),
                'triggers'=>self::words($m['triggers'] ?? []),'fields'=>$fields];
        }
        update_option(self::OPT, $clean, false);
        wp_safe_redirect(add_query_arg(['page'=>'neizami-mobile-voice','updated'=>1], admin_url('admin.php')));
        exit;
    }

    public static function page() {
        if (!current_user_can('manage_options')) return;
        $maps = get_option(self::OPT, []);
        if (!is_array($maps)) $maps = [];
        ?>
        <div class="wrap" dir="rtl" style="max-width:1050px">
          <h1>Voice Forms</h1>
          <p>كلمات تفعيل النموذج ثم كلمات تعبئة كل Field. يمكن وضع أكثر من كلمة مفصولة بفاصلة.</p>
          <?php if(isset($_GET['updated'])) echo '<div class="notice notice-success"><p>تم الحفظ.</p></div>'; ?>
          <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" id="nzvf">
            <?php wp_nonce_field('nz_mobile_voice_save'); ?>
            <input type="hidden" name="action" value="nz_mobile_voice_save">
            <input type="hidden" name="voice_maps_json" id="nzvf-json">
            <div id="nzvf-root"></div>
            <p><button type="button" class="button" id="nzvf-add">+ إضافة Form</button></p>
            <?php submit_button('حفظ'); ?>
          </form>
        </div>
        <style>
        .nzvf-card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:15px;margin:12px 0}
        .nzvf-grid{display:grid;grid-template-columns:1fr 1fr auto;gap:9px}.nzvf-field{display:grid;grid-template-columns:1fr 1fr 1.4fr auto;gap:8px;margin-top:8px}
        .nzvf-card input{width:100%}.nzvf-card label span{display:block;font-weight:700;margin:5px 0}
        @media(max-width:780px){.nzvf-grid,.nzvf-field{grid-template-columns:1fr}}
        </style>
        <script>
        (()=>{let d=<?php echo wp_json_encode(array_values($maps)); ?>;const r=document.getElementById('nzvf-root');
        const e=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
        const w=v=>Array.isArray(v)?v.join('، '):(v||'');
        function draw(){r.innerHTML=d.map((f,i)=>`<div class="nzvf-card"><div class="nzvf-grid">
        <label><span>Form Key</span><input data-i="${i}" data-k="form_key" value="${e(f.form_key)}"></label>
        <label><span>اسم النموذج</span><input data-i="${i}" data-k="label" value="${e(f.label)}"></label>
        <button type="button" class="button del-form" data-i="${i}">حذف</button></div>
        <label><span>كلمات تفعيل النموذج</span><input data-i="${i}" data-k="triggers" value="${e(w(f.triggers))}"></label>
        <hr><strong>Fields</strong>${(f.fields||[]).map((x,j)=>`<div class="nzvf-field">
        <label><span>Field Key</span><input data-i="${i}" data-j="${j}" data-f="field_key" value="${e(x.field_key)}"></label>
        <label><span>اسم الحقل</span><input data-i="${i}" data-j="${j}" data-f="label" value="${e(x.label)}"></label>
        <label><span>كلمات الحقل</span><input data-i="${i}" data-j="${j}" data-f="triggers" value="${e(w(x.triggers))}"></label>
        <button type="button" class="button del-field" data-i="${i}" data-j="${j}">حذف</button></div>`).join('')}
        <p><button type="button" class="button add-field" data-i="${i}">+ Field</button></p></div>`).join('');
        r.querySelectorAll('input').forEach(x=>x.oninput=()=>{let f=d[+x.dataset.i];if(x.dataset.k)f[x.dataset.k]=x.value;else f.fields[+x.dataset.j][x.dataset.f]=x.value});
        r.querySelectorAll('.add-field').forEach(b=>b.onclick=()=>{let f=d[+b.dataset.i];f.fields=f.fields||[];f.fields.push({field_key:'',label:'',triggers:''});draw()});
        r.querySelectorAll('.del-field').forEach(b=>b.onclick=()=>{d[+b.dataset.i].fields.splice(+b.dataset.j,1);draw()});
        r.querySelectorAll('.del-form').forEach(b=>b.onclick=()=>{d.splice(+b.dataset.i,1);draw()});}
        document.getElementById('nzvf-add').onclick=()=>{d.push({form_key:'',label:'',triggers:'',fields:[]});draw()};
        document.getElementById('nzvf').onsubmit=()=>document.getElementById('nzvf-json').value=JSON.stringify(d);draw();})();
        </script><?php
    }
}
NZ_Mobile_Voice_Forms::boot();
