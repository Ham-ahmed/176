#!/bin/sh
set -e  # إيقاف التنفيذ عند أي خطأ

# ============================================
# إعدادات المتغيرات
# ============================================
channel="Hazem-Wahba"
version="motor"
REMOTE_URL="https://raw.githubusercontent.com/Ham-ahmed/176/refs/heads/main/channels_backup_OpenBH_20260616_HAZEMWAHBA.tar.gz"
REMOTE_FILENAME="channels_${channel}.tar.gz"
LOCAL_PATH="/var/volatile/tmp/${REMOTE_FILENAME}"
BACKUP_DIR="/tmp/enigma2_backup_$(date +%Y%m%d_%H%M%S)"

# ============================================
# دوال مساعدة
# ============================================
print_header() {
    echo "*********************************************************"
    echo "*     $1"
    echo "*********************************************************"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "❌ خطأ: هذا السكريبت يحتاج إلى صلاحيات الجذر (root)"
        echo "يرجى التشغيل كالتالي: sudo $0"
        exit 1
    fi
}

check_requirements() {
    local missing=""
    for cmd in wget tar grep; do
        if ! command -v $cmd > /dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        echo "❌ الأدوات التالية غير مثبتة:$missing"
        echo "يرجى تثبيتها ثم إعادة المحاولة"
        exit 1
    fi
}

backup_old_channels() {
    if [ -d "/etc/enigma2" ] && [ "$(ls -A /etc/enigma2/*.tv 2>/dev/null)" ]; then
        echo "> إنشاء نسخة احتياطية من القنوات القديمة..."
        mkdir -p "$BACKUP_DIR"
        cp -r /etc/enigma2/lamedb "$BACKUP_DIR/" 2>/dev/null || true
        cp -r /etc/enigma2/userbouquet.* "$BACKUP_DIR/" 2>/dev/null || true
        echo "✅ النسخة الاحتياطية تم حفظها في: $BACKUP_DIR"
    fi
}

# ============================================
# التحقق من المتطلبات
# ============================================
check_root
check_requirements

# ============================================
# البدء في التحميل
# ============================================
print_header "Downloading $channel $version Channels List"
echo "> جاري التحضير..."
sleep 2

# الانتقال إلى المجلد المؤقت
cd /var/volatile/tmp

# تحميل الملف
echo "> جاري التحميل من GitLab..."
if wget -O "$LOCAL_PATH" "$REMOTE_URL" 2>&1; then
    if [ -s "$LOCAL_PATH" ]; then
        echo "✅ تم التحميل بنجاح!"
    else
        echo "❌ الملف المحمل فارغ!"
        exit 1
    fi
else
    echo "❌ فشل التحميل! يرجى التحقق من اتصال الإنترنت"
    exit 1
fi

# التحقق من نوع الملف
if ! file "$LOCAL_PATH" | grep -q "gzip compressed data"; then
    echo "❌ الملف ليس بصيغة tar.gz صحيحة!"
    rm -f "$LOCAL_PATH"
    exit 1
fi

# ============================================
# تثبيت القنوات الجديدة
# ============================================
echo ""
print_header "Installing $channel $version Channels List"

# إنشاء نسخة احتياطية قبل الحذف
backup_old_channels

echo "> حذف القنوات القديمة..."
# حذف آمن مع التحقق من المسار
[ -f "/etc/enigma2/lamedb" ] && rm -f /etc/enigma2/lamedb
rm -f /etc/enigma2/*.tv 2>/dev/null
rm -f /etc/enigma2/*.radio 2>/dev/null
rm -f /etc/enigma2/blacklist 2>/dev/null
rm -f /etc/enigma2/whitelist 2>/dev/null
rm -f /etc/enigma2/userbouquet.* 2>/dev/null
rm -f /etc/tuxbox/*.xml 2>/dev/null

echo "> فك الضغط..."
if tar -xzf "$LOCAL_PATH" -C /; then
    echo "✅ تم فك الضغط بنجاح!"
else
    echo "❌ فشل فك الضغط! الملف قد يكون تالفاً"
    rm -f "$LOCAL_PATH"
    exit 1
fi

# تنظيف الملف المؤقت
rm -f "$LOCAL_PATH"

# ============================================
# إعادة تشغيل الخدمات
# ============================================
echo ""
echo "> إعادة تحميل الخدمات..."

# محاولة إعادة تحميل القنوات عبر واجهة الويب
if command -v wget > /dev/null; then
    wget -qO - http://127.0.0.1/web/servicelistreload?mode=0 > /dev/null 2>&1 || true
fi

sleep 2

# ============================================
# إعادة تشغيل الواجهة الرسومية
# ============================================
print_header "Enigma2 GUI Restarting"
echo "> سيتم إعادة تشغيل الواجهة خلال 3 ثوان..."
sleep 3

# طريقة آمنة لإعادة التشغيل
if command -v systemctl > /dev/null 2>&1; then
    systemctl restart enigma2 2>/dev/null || systemctl restart enigma2.service
elif [ -f "/etc/init.d/enigma2" ]; then
    /etc/init.d/enigma2 restart
else
    # الطريقة التقليدية
    init 4
    sleep 2
    init 3
fi

# ============================================
# الاكتمال
# ============================================
echo ""
print_header "✅ Installation Completed Successfully!"
echo "*     Enjoy your $channel $version channels!            *"
echo "*     نسخة احتياطية موجودة في: $BACKUP_DIR     *"
echo "*********************************************************"

exit 0