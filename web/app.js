/* ==========================================================================
   kn_gps3d / /gpsedit パネル

   Lua から送られてくるスキーマ (config/editor.lua 由来) だけを見て UI を組む。
   項目の種類を増やすときは RENDERERS にレンダラを 1 つ足す。

   値の検証は Lua 側 (client/editor.lua) が最終的に行う。ここでのクランプは
   あくまで操作感のためのもので、安全性はここに依存していない。
   ========================================================================== */

(function () {
    'use strict';

    var RESOURCE = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'kn_gps3d';

    var panel = document.getElementById('panel');
    var bodyEl = document.getElementById('body');
    var titleEl = document.getElementById('title');
    var subtitleEl = document.getElementById('subtitle');
    var statusEl = document.getElementById('status');
    var resetAllBtn = document.getElementById('reset-all');
    var closeBtn = document.getElementById('close');

    var text = {};
    var fields = {};        // id -> { def, refs }
    var resetArmed = false;
    var statusTimer = null;

    /* ---------------------------------------------------------------- NUI */

    function post(name, data) {
        return fetch('https://' + RESOURCE + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(function (res) {
            return res.json();
        }).catch(function () {
            return { ok: false };
        });
    }

    /*
     ドラッグ中は 1 フレームに 1 回だけ送る。
     スライダーや色は入力が細かく、毎イベント送ると NUI 往復が詰まるため。
    */
    var pending = {};
    var frameQueued = false;

    function flush() {
        frameQueued = false;
        var ids = Object.keys(pending);
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            var value = pending[id];
            delete pending[id];
            post('set', { id: id, value: value });
        }
        markDirty(ids);
    }

    function sendValue(id, value) {
        pending[id] = value;
        if (!frameQueued) {
            frameQueued = true;
            requestAnimationFrame(flush);
        }
    }

    function markDirty(ids) {
        for (var i = 0; i < ids.length; i++) {
            var entry = fields[ids[i]];
            if (entry && entry.setDirty) {
                entry.setDirty(true);
            }
        }
    }

    function showStatus(message) {
        statusEl.textContent = message;
        statusEl.classList.add('show');
        clearTimeout(statusTimer);
        statusTimer = setTimeout(function () {
            statusEl.classList.remove('show');
        }, 1400);
    }

    /* ------------------------------------------------------------- helpers */

    function el(tag, className, parent) {
        var node = document.createElement(tag);
        if (className) {
            node.className = className;
        }
        if (parent) {
            parent.appendChild(node);
        }
        return node;
    }

    function clamp(value, min, max) {
        return Math.min(max, Math.max(min, value));
    }

    function formatNumber(value, decimals) {
        var d = (typeof decimals === 'number') ? decimals : 2;
        return Number(value).toFixed(d);
    }

    /* HSV <-> RGB (h: 0-360, s/v: 0-1, rgb: 0-255) */

    function hsvToRgb(h, s, v) {
        var c = v * s;
        var x = c * (1 - Math.abs(((h / 60) % 2) - 1));
        var m = v - c;
        var r = 0, g = 0, b = 0;

        if (h < 60) { r = c; g = x; }
        else if (h < 120) { r = x; g = c; }
        else if (h < 180) { g = c; b = x; }
        else if (h < 240) { g = x; b = c; }
        else if (h < 300) { r = x; b = c; }
        else { r = c; b = x; }

        return {
            r: Math.round((r + m) * 255),
            g: Math.round((g + m) * 255),
            b: Math.round((b + m) * 255)
        };
    }

    function rgbToHsv(r, g, b) {
        var rn = r / 255, gn = g / 255, bn = b / 255;
        var max = Math.max(rn, gn, bn);
        var min = Math.min(rn, gn, bn);
        var d = max - min;
        var h = 0;

        if (d !== 0) {
            if (max === rn) { h = 60 * (((gn - bn) / d) % 6); }
            else if (max === gn) { h = 60 * (((bn - rn) / d) + 2); }
            else { h = 60 * (((rn - gn) / d) + 4); }
        }

        if (h < 0) { h += 360; }

        return { h: h, s: max === 0 ? 0 : d / max, v: max };
    }

    /*
     ポインタ操作を要素内の 0-1 座標へ落とす共通処理。
     setPointerCapture により要素外へドラッグしても追従する。
    */
    function bindDrag(node, onMove) {
        function handle(event) {
            var rect = node.getBoundingClientRect();
            onMove(
                clamp((event.clientX - rect.left) / rect.width, 0, 1),
                clamp((event.clientY - rect.top) / rect.height, 0, 1)
            );
        }

        node.addEventListener('pointerdown', function (event) {
            node.setPointerCapture(event.pointerId);
            handle(event);
            event.preventDefault();
        });

        node.addEventListener('pointermove', function (event) {
            if (node.hasPointerCapture(event.pointerId)) {
                handle(event);
            }
        });

        node.addEventListener('pointerup', function (event) {
            if (node.hasPointerCapture(event.pointerId)) {
                node.releasePointerCapture(event.pointerId);
            }
        });
    }

    /* ----------------------------------------------------------- renderers */

    function fieldHead(parent, def, opts) {
        var head = el('div', 'field-head', parent);
        var label = el('span', 'field-label', head);
        label.textContent = def.label;

        var valueEl = null;
        if (opts && opts.value) {
            valueEl = el('span', 'field-value', head);
        }

        var resetBtn = el('button', 'reset-btn', head);
        resetBtn.type = 'button';
        resetBtn.textContent = '↺';
        resetBtn.title = text.reset || 'Reset';

        return { head: head, valueEl: valueEl, resetBtn: resetBtn };
    }

    /*
     リセットボタンの共通配線。
     Lua が戻した実効値で UI を更新するので、戻し先の判断は Lua 側だけに置ける。
    */
    function bindReset(def, resetBtn, apply) {
        var setDirty = function (dirty) {
            resetBtn.classList.toggle('show', !!dirty);
        };

        setDirty(def.dirty);

        resetBtn.addEventListener('click', function () {
            post('reset', { id: def.id }).then(function (res) {
                if (!res || !res.ok) {
                    return;
                }
                // 基底値が総入れ替えになる項目 (プリセット) はパネルごと作り直す
                if (res.payload) {
                    renderSafe(res.payload);
                    return;
                }
                apply(res.value);
                setDirty(false);
            });
        });

        return setDirty;
    }

    var RENDERERS = {
        toggle: function (parent, def) {
            var refs = fieldHead(parent, def, {});
            var sw = el('button', 'switch', refs.head);
            sw.type = 'button';

            var current = def.value === true;

            function apply(value) {
                current = value === true;
                sw.classList.toggle('on', current);
            }

            apply(def.value);

            sw.addEventListener('click', function () {
                apply(!current);
                sendValue(def.id, current);
            });

            return { setDirty: bindReset(def, refs.resetBtn, apply) };
        },

        slider: function (parent, def) {
            var refs = fieldHead(parent, def, { value: true });
            var input = el('input', 'slider', parent);
            input.type = 'range';
            input.min = def.min;
            input.max = def.max;
            input.step = def.step;

            function apply(value) {
                var numeric = Number(value);
                if (!isFinite(numeric)) {
                    numeric = Number(def.min);
                }
                numeric = clamp(numeric, Number(def.min), Number(def.max));
                input.value = numeric;
                refs.valueEl.textContent = formatNumber(numeric, def.decimals);
            }

            apply(def.value);

            input.addEventListener('input', function () {
                var numeric = Number(input.value);
                refs.valueEl.textContent = formatNumber(numeric, def.decimals);
                sendValue(def.id, numeric);
            });

            return { setDirty: bindReset(def, refs.resetBtn, apply) };
        },

        choice: function (parent, def) {
            var refs = fieldHead(parent, def, {});
            var row = el('div', 'choice', parent);
            var buttons = [];

            function apply(value) {
                for (var i = 0; i < buttons.length; i++) {
                    buttons[i].classList.toggle('on', buttons[i].dataset.value === String(value));
                }
            }

            (def.options || []).forEach(function (option) {
                var btn = el('button', null, row);
                btn.type = 'button';
                btn.textContent = option.label;
                btn.dataset.value = String(option.value);
                btn.addEventListener('click', function () {
                    apply(option.value);
                    sendValue(def.id, option.value);
                });
                buttons.push(btn);
            });

            apply(def.value);

            return { setDirty: bindReset(def, refs.resetBtn, apply) };
        },

        /*
         プリセット選択。
         一覧をインラインで開き、使用中の行にアクセント (左のバー + ✓ + 太字) を付ける。
         各行にはテクスチャのサムネイルを出す (web/thumb/<textureName>.png)。
        */
        preset: function (parent, def) {
            var refs = fieldHead(parent, def, {});
            var picker = el('div', 'picker', parent);
            var current = el('button', 'picker-current', picker);
            current.type = 'button';

            var currentThumb = el('span', 'picker-thumb', current);
            var currentName = el('span', 'picker-name', current);
            var currentIndex = el('span', 'picker-index', current);
            var caret = el('span', 'picker-caret', current);
            caret.textContent = '▼';

            var list = el('div', 'picker-list', picker);
            var rows = [];
            var options = def.options || [];

            function thumbStyle(node, option) {
                if (option && option.texture) {
                    node.style.backgroundImage = 'url("thumb/' + option.texture + '.png")';
                } else {
                    node.style.backgroundImage = '';
                }
            }

            function apply(value) {
                var found = null;
                for (var i = 0; i < options.length; i++) {
                    var on = String(options[i].value) === String(value);
                    rows[i].classList.toggle('active', on);
                    if (on) {
                        found = options[i];
                    }
                }

                currentName.textContent = found ? found.label : '—';
                currentIndex.textContent = found ? String(found.value) : '';
                thumbStyle(currentThumb, found);
            }

            options.forEach(function (option) {
                var row = el('button', 'picker-item', list);
                row.type = 'button';

                var thumb = el('span', 'picker-thumb', row);
                thumbStyle(thumb, option);

                var name = el('span', 'picker-name', row);
                name.textContent = option.label;

                var index = el('span', 'picker-index', row);
                index.textContent = String(option.value);

                var check = el('span', 'picker-check', row);
                check.textContent = '✓';

                row.addEventListener('click', function () {
                    picker.classList.remove('open');
                    apply(option.value);
                    // プリセットは基底値が総入れ替えになるので応答でパネルごと組み直す
                    post('set', { id: def.id, value: Number(option.value) }).then(function (res) {
                        if (res && res.ok && res.payload) {
                            renderSafe(res.payload);
                        }
                    });
                });

                rows.push(row);
            });

            current.addEventListener('click', function () {
                var open = picker.classList.toggle('open');
                if (!open) {
                    return;
                }
                // 開いたときに使用中の行を見える位置へ (スクロールするのはパネル本体)
                for (var i = 0; i < rows.length; i++) {
                    if (rows[i].classList.contains('active')) {
                        if (rows[i].scrollIntoView) {
                            rows[i].scrollIntoView({ block: 'nearest' });
                        }
                        break;
                    }
                }
            });

            apply(def.value);

            return { setDirty: bindReset(def, refs.resetBtn, apply) };
        },

        /*
         色ウィジェット。
         タブごとに独立した設定値 (id) を持ち、選択中のタブの id へ送る。
        */
        color: function (parent, def) {
            var head = el('div', 'field-head', parent);
            var label = el('span', 'field-label', head);
            label.textContent = def.label;

            // 右端そろえは .field-label の flex が担うので margin-left:auto は不要
            var swatch = el('span', 'swatch', head);

            var resetBtn = el('button', 'reset-btn', head);
            resetBtn.type = 'button';
            resetBtn.textContent = '↺';
            resetBtn.title = text.reset || 'Reset';

            var tabsRow = el('div', 'color-tabs', parent);
            var sv = el('div', 'sv', parent);
            var svKnob = el('div', 'sv-knob', sv);
            var hue = el('div', 'hue', parent);
            var hueKnob = el('div', 'hue-knob', hue);

            var alphaRow = el('div', 'alpha-row', parent);
            var alpha = el('input', 'slider', alphaRow);
            alpha.type = 'range';
            alpha.min = 0;
            alpha.max = 255;
            alpha.step = 1;

            var tabs = (def.tabs || []).slice();
            var active = 0;
            var hsv = { h: 0, s: 1, v: 1 };
            var alphaValue = 255;

            function currentTab() {
                return tabs[active] || { id: '', value: { r: 255, g: 255, b: 255, a: 255 } };
            }

            function paint() {
                var rgb = hsvToRgb(hsv.h, hsv.s, hsv.v);
                var pure = hsvToRgb(hsv.h, 1, 1);

                sv.style.background =
                    'linear-gradient(to top, #000, rgba(0,0,0,0)),' +
                    'linear-gradient(to right, #fff, rgb(' + pure.r + ',' + pure.g + ',' + pure.b + '))';

                /*
                 つまみを枠の内側だけで動かす。
                 単純な % 配置だと端で半径ぶん (7px) 枠からはみ出してバリになる。
                */
                svKnob.style.left = 'calc(7px + (100% - 14px) * ' + hsv.s + ')';
                svKnob.style.top = 'calc(7px + (100% - 14px) * ' + (1 - hsv.v) + ')';
                hueKnob.style.left = 'calc(7px + (100% - 14px) * ' + (hsv.h / 360) + ')';

                swatch.style.background =
                    'rgba(' + rgb.r + ',' + rgb.g + ',' + rgb.b + ',' + (alphaValue / 255) + ')';

                return rgb;
            }

            function loadTab() {
                var tab = currentTab();
                var value = tab.value || { r: 255, g: 255, b: 255, a: 255 };
                hsv = rgbToHsv(value.r, value.g, value.b);
                alphaValue = (typeof value.a === 'number') ? value.a : 255;
                alpha.value = alphaValue;
                resetBtn.classList.toggle('show', !!tab.dirty);
                paint();
            }

            function emit() {
                var rgb = paint();
                var tab = currentTab();
                tab.value = { r: rgb.r, g: rgb.g, b: rgb.b, a: alphaValue };
                tab.dirty = true;
                resetBtn.classList.add('show');
                sendValue(tab.id, tab.value);
            }

            tabs.forEach(function (tab, index) {
                var btn = el('button', null, tabsRow);
                btn.type = 'button';
                btn.textContent = tab.label;
                btn.addEventListener('click', function () {
                    active = index;
                    for (var i = 0; i < tabsRow.children.length; i++) {
                        tabsRow.children[i].classList.toggle('on', i === index);
                    }
                    loadTab();
                });
            });

            if (tabsRow.firstChild) {
                tabsRow.firstChild.classList.add('on');
            }

            bindDrag(sv, function (x, y) {
                hsv.s = x;
                hsv.v = 1 - y;
                emit();
            });

            bindDrag(hue, function (x) {
                hsv.h = x * 360;
                emit();
            });

            alpha.addEventListener('input', function () {
                alphaValue = Number(alpha.value);
                emit();
            });

            resetBtn.addEventListener('click', function () {
                var tab = currentTab();
                post('reset', { id: tab.id }).then(function (res) {
                    if (res && res.ok && res.value) {
                        tab.value = res.value;
                        tab.dirty = false;
                        loadTab();
                    }
                });
            });

            loadTab();

            // タブごとに dirty が違うので一括更新はしない
            return { setDirty: function () {} };
        }
    };

    /* -------------------------------------------------------------- render */

    function renderSafe(data) {
        try {
            render(data);
        } catch (err) {
            /*
             描画に失敗したままだとパネルが出ないのにフォーカスだけ奪われる。
             必ず閉じてゲームへ制御を戻す。
            */
            console.error('[kn_gps3d] render failed', err);
            hide();
            post('close');
        }
    }

    function render(data) {
        text = data.text || {};
        fields = {};
        bodyEl.innerHTML = '';

        titleEl.textContent = data.title || '';
        subtitleEl.textContent = data.subtitle || '';
        resetAllBtn.textContent = text.resetAll || 'Reset';
        resetAllBtn.classList.remove('armed');
        resetArmed = false;

        (data.sections || []).forEach(function (section) {
            var node = el('div', 'section', bodyEl);
            var label = el('div', 'section-label', node);
            label.textContent = section.label;

            (section.fields || []).forEach(function (def) {
                var renderer = RENDERERS[def.kind];
                if (!renderer) {
                    return;
                }

                var wrap = el('div', 'field', node);
                fields[def.id] = renderer(wrap, def);
            });
        });

        panel.classList.remove('hidden');
    }

    function hide() {
        panel.classList.add('hidden');
    }

    /* -------------------------------------------------------------- events */

    closeBtn.addEventListener('click', function () {
        hide();
        post('close');
    });

    /* 誤爆すると全設定が飛ぶので 2 度押しにする */
    resetAllBtn.addEventListener('click', function () {
        if (!resetArmed) {
            resetArmed = true;
            resetAllBtn.classList.add('armed');
            resetAllBtn.textContent = text.resetAllConfirm || 'Press again';
            setTimeout(function () {
                if (resetArmed) {
                    resetArmed = false;
                    resetAllBtn.classList.remove('armed');
                    resetAllBtn.textContent = text.resetAll || 'Reset';
                }
            }, 2600);
            return;
        }

        resetArmed = false;
        post('resetAll').then(function (res) {
            if (res && res.ok && res.payload) {
                renderSafe(res.payload);
                showStatus(text.saved || '');
            }
        });
    });

    document.addEventListener('keyup', function (event) {
        if (event.key === 'Escape' || event.code === 'Escape') {
            hide();
            post('close');
        }
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};

        if (data.action === 'open') {
            renderSafe(data);
        } else if (data.action === 'close') {
            hide();
        }
    });

    /*
     リソース起動直後は RegisterNUICallback がまだ登録されておらず ready が
     404 になりうる。応答が返るまで数回リトライする。
     Lua 側は ready を受け取るまでパネルを開かない (フォーカス取られっぱなし防止)。
    */
    (function announceReady(attempt) {
        post('ready').then(function (res) {
            if (res && res.ok) {
                return;
            }
            if (attempt < 10) {
                setTimeout(function () {
                    announceReady(attempt + 1);
                }, 1000);
            }
        });
    }(0));
}());
