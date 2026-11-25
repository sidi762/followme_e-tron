# Follow Me e-tron 手柄配置指南（扳机油门 / 刹车）

本文档适用于在 FlightGear 中使用 **Xbox / PlayStation (DualSense / DualShock) / 通用手柄** 驾驶 `followme_e-tron`（尤其是带 2D Pedal Map 的轮胎模型版本 `followme_e-tron-tyre`）。

---

## 核心映射关系

| 手柄操作 | FlightGear 属性 | 范围 | 说明 |
|---|---|---|---|
| **右扳机 (RT / R2)** 油门 | `/controls/engines/engine/throttle` | `0.0 ~ 1.0` | 线性输入，自动进入 2D Pedal Map |
| **左扳机 (LT / L2)** 刹车 | `/controls/gear/brake-left` 和 `/controls/gear/brake-right` | `0.0 ~ 1.0` | **必须同时控制前后轴**（left=前轴，right=后轴） |
| **左摇杆左右 (LX)** 转向 | `/controls/flight/rudder` | `-1.0 ~ +1.0` | 控制前轮转向 |

> **为什么不直接用 FlightGear 菜单里的 Joystick Configuration 绑刹车？**  
> 菜单界面里一条轴只能绑一个属性；如果只绑 `brake-left`，就只有前轮有刹车。编辑 XML 配置文件可以一次同时控制前后轴，而且能加底部死区，防止扳机回弹不彻底导致滑行回收不工作。

---

## 第一步：查看手柄名称和轴号

1. 连接手柄并启动 FlightGear，进入车内。
2. 打开菜单 **File → Joystick Configuration**：
   - 记下顶部显示的 **设备名称（Joystick Name）**。
   - 随便改一下再点保存/关闭，FlightGear 会在个人配置目录自动生成一份对应手柄的 `.xml` 文件（方便下一步直接编辑）。
3. 打开菜单 **Debug → Browse Internal Properties**，展开 `/input/joysticks/js[0]/`（如有多个设备可能是 `js[1]`）：
   - 逐一晃动 **左摇杆左右**、捏 **左扳机 (LT)**、捏 **右扳机 (RT)**，看 `axis[0]`、`axis[1]` … 哪个数值在变，记下对应的轴号 `n`。
   - 同时记下扳机 **松开** 和 **捏到底** 时的数值（常见为 **`-1.0` → `+1.0`**；少数驱动为 `0.0` → `+1.0`；部分 Windows 下的 Xbox 驱动会把 LT/RT 合并成同一条轴，松开 `0`，左捏 `-1`、右捏 `+1`）。

---

## 第二步：编辑手柄 XML 配置文件

找到你的 FlightGear 手柄配置目录：
- **Windows**：`%APPDATA%\flightgear.org\Input\Joysticks\`
- **macOS**：`~/Library/Application Support/FlightGear/Input/Joysticks/`
- **Linux**：`~/.fgfs/Input/Joysticks/`

打开刚才生成的 `.xml` 文件（或新建一个，例如 `xbox-followme.xml`），把下面的模板填进去，并将 `<name>` 和各 `<axis n="...">` 改成你在第一步查到的值。

### 情况 A：左右扳机是独立双轴，范围 `-1.0`（松开）到 `+1.0`（捏满）（最常见）

```xml
<?xml version="1.0"?>
<PropertyList>
    <!-- 改成第一步在 Joystick Configuration 里看到的完整设备名 -->
    <name>Xbox Wireless Controller</name>

    <!-- 左摇杆左右：转向（常见轴号 0） -->
    <axis n="0">
        <desc>Steering</desc>
        <dead-band type="double">0.05</dead-band>
        <binding>
            <command>property-scale</command>
            <property>/controls/flight/rudder</property>
            <power type="double">1.5</power>
        </binding>
    </axis>

    <!-- 右扳机 RT：油门（常见轴号 5；含 3% 底部死区防误触） -->
    <axis n="5">
        <desc>Accelerator</desc>
        <binding>
            <command>nasal</command>
            <script>
                var v = (cmdarg().getNode("setting").getValue() + 1.0) * 0.5;
                v = v &lt; 0.03 ? 0.0 : (v - 0.03) / 0.97;
                setprop("/controls/engines/engine/throttle", v);
            </script>
        </binding>
    </axis>

    <!-- 左扳机 LT：前后轴同步刹车（常见轴号 2；含 3% 底部死区） -->
    <axis n="2">
        <desc>Brakes</desc>
        <binding>
            <command>nasal</command>
            <script>
                var v = (cmdarg().getNode("setting").getValue() + 1.0) * 0.5;
                v = v &lt; 0.03 ? 0.0 : (v - 0.03) / 0.97;
                setprop("/controls/gear/brake-left", v);
                setprop("/controls/gear/brake-right", v);
            </script>
        </binding>
    </axis>

    <!-- 可选按键示例（按钮编号 n 同样可在 /input/joysticks/js[0]/button 里查） -->
    <!-- 切换前进/倒挡 (D/R) -->
    <!--
    <button n="3">
        <desc>Toggle D/R</desc>
        <binding>
            <command>nasal</command>
            <script>engine.engine_1.toggleDirection();</script>
        </binding>
    </button>
    -->

    <!-- 电子手刹开关 -->
    <!--
    <button n="1">
        <desc>Toggle Parking Brake</desc>
        <binding>
            <command>nasal</command>
            <script>followme.brakeController.toggleHandBrake();</script>
        </binding>
    </button>
    -->
</PropertyList>
```

> **如果扳机原始范围是 `0.0 ~ +1.0`**：把脚本里 `(cmdarg().getNode("setting").getValue() + 1.0) * 0.5` 改成 `cmdarg().getNode("setting").getValue()` 即可。

### 情况 B：Windows 下 LT / RT 合并在同一条轴（松开 `0`，左捏负值，右捏正值）

如果两个扳机共用同一条轴（假设轴号为 `2`），把上面两个扳机的 `<axis>` 换成下面这一段（注意确认哪边是正值；如果油门刹车反了，把正负号对调即可）：

```xml
    <axis n="2">
        <desc>Combined Trigger (RT Throttle / LT Brake)</desc>
        <binding>
            <command>nasal</command>
            <script>
                var raw = cmdarg().getNode("setting").getValue();
                var gas = raw &gt; 0.03 ? (raw - 0.03) / 0.97 : 0.0;
                var brk = raw &lt; -0.03 ? (-raw - 0.03) / 0.97 : 0.0;
                setprop("/controls/engines/engine/throttle", gas);
                setprop("/controls/gear/brake-left", brk);
                setprop("/controls/gear/brake-right", brk);
            </script>
        </binding>
    </axis>
```

---

## 第三步：生效与验证

1. 保存 XML 后，在 FlightGear 里点 **Debug → Reload Input**（或重启 FlightGear）。
2. **重要**：刚进车时先**轻捏一下左右扳机再松开**（很多手柄在首次触发前默认报 `0.0`，会被当成半踩）。
3. 打开 **Debug → Browse Internal Properties** 检查：
   - 松开双扳机：`/controls/engines/engine/throttle` = `0`，`/controls/gear/brake-left` = `0`，`/controls/gear/brake-right` = `0`。
   - 慢捏右扳机：`throttle` 从 `0` 平滑升到 `1`。
   - 慢捏左扳机：`brake-left` 和 `brake-right` 同步从 `0` 平滑升到 `1`。
   - 晃动左摇杆：`/controls/flight/rudder` 在 `-1 ~ +1` 之间平滑变化，回中为 `0`。

---

## 常见问题

- **松开油门后车还在慢慢加速 / 滑行回收不触发**：检查 `/controls/engines/engine/throttle` 松手时是否为精确 `0`，如果不为 `0`，把脚本里的死区 `0.03` 调大到 `0.05` 或 `0.08`。
- **油门和刹车方向反了（不踩满油、踩了归零）**：说明该手柄轴是反相的，把 `(setting + 1.0) * 0.5` 改成 `(1.0 - setting) * 0.5`。
- **只在 `followme_e-tron` 上生效，不影响开飞机**：上面的 `throttle`、`brake-left`、`brake-right`、`rudder` 都是 FlightGear 通用属性，开普通飞机时同样正常可用（除了注释掉的专属 Nasal 按钮）。
