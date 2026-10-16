package com.ps3mod;

import android.app.Activity;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Toast;

/**
 * PS3 (DualShock 3) full-controller mapper for Granny (DVloper).
 *
 * <p>Granny is a touch-only Unity game, so this mapper converts gamepad /
 * joystick input into synthetic touchscreen events and dispatches them to the
 * game activity. No special permissions are needed.
 *
 * <p>Mapping (fractions of screen size, landscape):
 * <ul>
 *   <li>Left stick / D-Pad ........ movement joystick (bottom-left)</li>
 *   <li>Right stick ................ look around (drag on right side)</li>
 *   <li>CROSS / R1 / R3 / DPadCenter  hand = grab / use / open (right side)</li>
 *   <li>CIRCLE / R2 ................ bottom action = drop / use / place / shoot / spray</li>
 *   <li>SQUARE / L2 ................ center action = hide / unhide & contextual center taps</li>
 *   <li>TRIANGLE / L1 / L3 / SELECT  crouch / stand (person icon, top-left)</li>
 *   <li>START ...................... pause menu (top-right)</li>
 *   <li>L3 + R3 together ........... toggle controller mapping ON/OFF</li>
 * </ul>
 *
 * <p>All entry points run on the UI thread (called from the activity's
 * dispatchKeyEvent / dispatchGenericMotionEvent overrides injected by the
 * patch script), so synthetic touches can be dispatched directly.
 */
public class PS3Mapper {

    // ------------------------------------------------------------------
    // Tuning: all coordinates are fractions of the decor-view size.
    // ------------------------------------------------------------------

    /** Movement joystick home (white circle, bottom-left). */
    private static final float MOVE_HOME_X = 0.105f;
    private static final float MOVE_HOME_Y = 0.815f;
    /** Stick travel radius, fraction of min(width, height). */
    private static final float MOVE_RADIUS = 0.085f;

    /** Look-drag anchor (empty area, right-center). */
    private static final float LOOK_HOME_X = 0.72f;
    private static final float LOOK_HOME_Y = 0.50f;
    /** Look stroke length, fraction of min(width, height). */
    private static final float LOOK_RADIUS = 0.16f;

    private static final float STICK_DEADZONE = 0.22f;
    private static final float LOOK_DEADZONE = 0.28f;

    /** Tap = down, then up after this delay. */
    private static final long TAP_RELEASE_MS = 90L;
    /** Look works by repeated strokes; this is the re-stroke period. */
    private static final long LOOK_RESTROKE_MS = 140L;
    /** L3+R3 combo window for the ON/OFF toggle. */
    private static final long TOGGLE_WINDOW_MS = 600L;
    /** Device-presence watchdog period (releases stuck pointers). */
    private static final long WATCHDOG_MS = 700L;

    // Button target spots: HAND / BOTTOM / CENTER / CROUCH / PAUSE.
    private static final int T_HAND = 0;
    private static final int T_BOTTOM = 1;
    private static final int T_CENTER = 2;
    private static final int T_CROUCH = 3;
    private static final int T_PAUSE = 4;
    private static final float[] TX = {0.905f, 0.500f, 0.500f, 0.045f, 0.962f};
    private static final float[] TY = {0.375f, 0.900f, 0.550f, 0.200f, 0.060f};

    // ------------------------------------------------------------------
    // Synthetic multi-touch engine (max 10 simultaneous pointers).
    // ------------------------------------------------------------------

    private static final int MAX_POINTERS = 10;
    private static final int PID_MOVE = 0;
    private static final int PID_LOOK = 1;

    private static final boolean[] pActive = new boolean[MAX_POINTERS];
    private static final float[] pX = new float[MAX_POINTERS];
    private static final float[] pY = new float[MAX_POINTERS];
    private static int pCount = 0;
    private static long gestureDownTime = 0L;

    private static Handler mainHandler = null;

    private static Handler handler() {
        if (mainHandler == null) {
            mainHandler = new Handler(Looper.getMainLooper());
        }
        return mainHandler;
    }

    private static int viewW(Activity a) {
        try {
            View v = a.getWindow().getDecorView();
            int w = v.getWidth();
            if (w > 0) {
                return w;
            }
        } catch (Throwable ignored) {
        }
        return a.getResources().getDisplayMetrics().widthPixels;
    }

    private static int viewH(Activity a) {
        try {
            View v = a.getWindow().getDecorView();
            int h = v.getHeight();
            if (h > 0) {
                return h;
            }
        } catch (Throwable ignored) {
        }
        return a.getResources().getDisplayMetrics().heightPixels;
    }

    /** Build a MotionEvent from current pointer state and dispatch it. */
    private static void pushEvent(Activity a, int action, int actionPid) {
        int n = 0;
        for (int i = 0; i < MAX_POINTERS; i++) {
            if (pActive[i]) {
                n++;
            }
        }
        if (n == 0) {
            return;
        }
        MotionEvent.PointerProperties[] props = new MotionEvent.PointerProperties[n];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[n];
        int k = 0;
        int actionIndex = 0;
        for (int i = 0; i < MAX_POINTERS && k < n; i++) {
            if (!pActive[i]) {
                continue;
            }
            MotionEvent.PointerProperties pp = new MotionEvent.PointerProperties();
            pp.id = i;
            pp.toolType = MotionEvent.TOOL_TYPE_FINGER;
            props[k] = pp;
            MotionEvent.PointerCoords pc = new MotionEvent.PointerCoords();
            pc.x = pX[i];
            pc.y = pY[i];
            pc.pressure = 1.0f;
            pc.size = 1.0f;
            coords[k] = pc;
            if (i == actionPid) {
                actionIndex = k;
            }
            k++;
        }
        int act = action;
        if (action == MotionEvent.ACTION_POINTER_DOWN
                || action == MotionEvent.ACTION_POINTER_UP) {
            act = action | (actionIndex << MotionEvent.ACTION_POINTER_INDEX_SHIFT);
        }
        long now = SystemClock.uptimeMillis();
        MotionEvent ev = null;
        try {
            ev = MotionEvent.obtain(gestureDownTime, now, act, n, props, coords,
                    0, 0, 1.0f, 1.0f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
            a.dispatchTouchEvent(ev);
        } catch (Throwable ignored) {
        } finally {
            if (ev != null) {
                ev.recycle();
            }
        }
    }

    /** Press (or move, if already down) a pointer. */
    private static void ptrDown(Activity a, int pid, float x, float y) {
        if (pid < 0 || pid >= MAX_POINTERS) {
            return;
        }
        if (pActive[pid]) {
            pX[pid] = x;
            pY[pid] = y;
            ptrMove(a);
            return;
        }
        if (pCount == 0) {
            gestureDownTime = SystemClock.uptimeMillis();
        }
        pActive[pid] = true;
        pX[pid] = x;
        pY[pid] = y;
        pCount++;
        pushEvent(a, pCount == 1 ? MotionEvent.ACTION_DOWN
                : MotionEvent.ACTION_POINTER_DOWN, pid);
    }

    private static void ptrMove(Activity a) {
        if (pCount == 0) {
            return;
        }
        pushEvent(a, MotionEvent.ACTION_MOVE, -1);
    }

    private static void ptrUp(Activity a, int pid) {
        if (pid < 0 || pid >= MAX_POINTERS || !pActive[pid]) {
            return;
        }
        pushEvent(a, pCount == 1 ? MotionEvent.ACTION_UP
                : MotionEvent.ACTION_POINTER_UP, pid);
        pActive[pid] = false;
        pCount--;
    }

    private static void releaseAll(Activity a) {
        for (int i = MAX_POINTERS - 1; i >= 0; i--) {
            if (pActive[i]) {
                ptrUp(a, i);
            }
        }
    }

    private static int allocPid() {
        for (int i = 2; i < MAX_POINTERS; i++) {
            if (!pActive[i]) {
                return i;
            }
        }
        return 2;
    }

    // ------------------------------------------------------------------
    // Global state.
    // ------------------------------------------------------------------

    private static boolean enabled = true;
    private static boolean toasted = false;

    private static void toastOnce(Activity a) {
        if (toasted) {
            return;
        }
        toasted = true;
        try {
            Toast.makeText(a.getApplicationContext(),
                    "PS3 controller connected - full support ON",
                    Toast.LENGTH_LONG).show();
        } catch (Throwable ignored) {
        }
    }

    private static void toast(Activity a, String msg) {
        try {
            Toast.makeText(a.getApplicationContext(), msg, Toast.LENGTH_SHORT).show();
        } catch (Throwable ignored) {
        }
    }

    private static void toggleEnabled(Activity a) {
        enabled = !enabled;
        if (!enabled) {
            moveOn = false;
            moveGen++;
            lookOn = false;
            lookGen++;
            dUp = dDown = dLeft = dRight = false;
            releaseAll(a);
            toast(a, "PS3 mapping OFF (touch only) - L3+R3 to re-enable");
        } else {
            toast(a, "PS3 mapping ON");
        }
    }

    // ------------------------------------------------------------------
    // Movement (left stick + D-Pad merged).
    // ------------------------------------------------------------------

    private static boolean moveOn = false;
    private static int moveGen = 0;
    private static int moveDevId = -1;
    private static float lastAx = 0f;
    private static float lastAy = 0f;
    private static boolean dUp = false;
    private static boolean dDown = false;
    private static boolean dLeft = false;
    private static boolean dRight = false;

    private static float clamp1(float v) {
        if (v > 1f) {
            return 1f;
        }
        if (v < -1f) {
            return -1f;
        }
        return v;
    }

    private static float applyDeadzone(float v, float dead) {
        float a = Math.abs(v);
        if (a < dead) {
            return 0f;
        }
        float scaled = (a - dead) / (1f - dead);
        if (scaled > 1f) {
            scaled = 1f;
        }
        return v < 0 ? -scaled : scaled;
    }

    private static void updateMove(Activity a) {
        float x = lastAx;
        float y = lastAy;
        if (dLeft) {
            x -= 1f;
        }
        if (dRight) {
            x += 1f;
        }
        if (dUp) {
            y -= 1f;
        }
        if (dDown) {
            y += 1f;
        }
        float mag = (float) Math.sqrt(x * x + y * y);
        if (mag > 1f) {
            x /= mag;
            y /= mag;
            mag = 1f;
        }
        if (mag < 0.03f) {
            if (moveOn) {
                moveOn = false;
                moveGen++;
                ptrUp(a, PID_MOVE);
            }
            return;
        }
        int w = viewW(a);
        int h = viewH(a);
        int m = Math.min(w, h);
        float px = MOVE_HOME_X * w + x * MOVE_RADIUS * m;
        float py = MOVE_HOME_Y * h + y * MOVE_RADIUS * m;
        if (!moveOn) {
            moveOn = true;
            moveGen++;
            ptrDown(a, PID_MOVE, px, py);
            postMoveWatch(a, moveGen);
        } else {
            pX[PID_MOVE] = px;
            pY[PID_MOVE] = py;
            ptrMove(a);
        }
    }

    private static void postMoveWatch(final Activity a, final int gen) {
        handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (gen != moveGen || !moveOn) {
                    return;
                }
                if (moveDevId >= 0 && InputDevice.getDevice(moveDevId) == null) {
                    // Controller disconnected while moving: release the stuck finger.
                    moveOn = false;
                    ptrUp(a, PID_MOVE);
                    return;
                }
                postMoveWatch(a, gen);
            }
        }, WATCHDOG_MS);
    }

    // ------------------------------------------------------------------
    // Look (right stick -> repeated drag strokes).
    // ------------------------------------------------------------------

    private static boolean lookOn = false;
    private static int lookGen = 0;
    private static int lookDevId = -1;
    private static float lookRx = 0f;
    private static float lookRy = 0f;

    private static void setLook(Activity a, float rx, float ry, int devId) {
        float mag = (float) Math.sqrt(rx * rx + ry * ry);
        if (mag < 0.03f) {
            if (lookOn) {
                lookOn = false;
                lookGen++;
                ptrUp(a, PID_LOOK);
            }
            return;
        }
        lookRx = rx;
        lookRy = ry;
        lookDevId = devId;
        if (!lookOn) {
            lookOn = true;
            lookGen++;
            lookStroke(a);
            postLookRestroke(a, lookGen);
        } else {
            moveLookPointer(a);
        }
    }

    /** Press at anchor, then drag to the deflected target. */
    private static void lookStroke(Activity a) {
        int w = viewW(a);
        int h = viewH(a);
        int m = Math.min(w, h);
        float ax = LOOK_HOME_X * w;
        float ay = LOOK_HOME_Y * h;
        ptrDown(a, PID_LOOK, ax, ay);
        moveLookPointer(a);
    }

    private static void moveLookPointer(Activity a) {
        int w = viewW(a);
        int h = viewH(a);
        int m = Math.min(w, h);
        pX[PID_LOOK] = LOOK_HOME_X * w + lookRx * LOOK_RADIUS * m;
        pY[PID_LOOK] = LOOK_HOME_Y * h + lookRy * LOOK_RADIUS * m;
        ptrMove(a);
    }

    private static void postLookRestroke(final Activity a, final int gen) {
        handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                if (gen != lookGen || !lookOn) {
                    return;
                }
                if (lookDevId >= 0 && InputDevice.getDevice(lookDevId) == null) {
                    // Controller disconnected mid-look: release the stuck finger.
                    lookOn = false;
                    ptrUp(a, PID_LOOK);
                    return;
                }
                // Lift and re-press so the game keeps turning (drag is relative).
                ptrUp(a, PID_LOOK);
                lookStroke(a);
                postLookRestroke(a, gen);
            }
        }, LOOK_RESTROKE_MS);
    }

    // ------------------------------------------------------------------
    // Button taps.
    // ------------------------------------------------------------------

    private static void tap(Activity a, int target) {
        int w = viewW(a);
        int h = viewH(a);
        final int pid = allocPid();
        ptrDown(a, pid, TX[target] * w, TY[target] * h);
        final Activity act = a;
        handler().postDelayed(new Runnable() {
            @Override
            public void run() {
                ptrUp(act, pid);
            }
        }, TAP_RELEASE_MS);
    }

    /** Map a gamepad button to a touch target, or -1 if unmapped. */
    private static int targetFor(int keyCode) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_BUTTON_A:      // CROSS
            case KeyEvent.KEYCODE_BUTTON_R1:
            case KeyEvent.KEYCODE_BUTTON_THUMBR: // R3
            case KeyEvent.KEYCODE_DPAD_CENTER:
                return T_HAND;
            case KeyEvent.KEYCODE_BUTTON_B:      // CIRCLE
            case KeyEvent.KEYCODE_BUTTON_R2:
                return T_BOTTOM;
            case KeyEvent.KEYCODE_BUTTON_X:      // SQUARE
            case KeyEvent.KEYCODE_BUTTON_L2:
                return T_CENTER;
            case KeyEvent.KEYCODE_BUTTON_Y:      // TRIANGLE
            case KeyEvent.KEYCODE_BUTTON_L1:
            case KeyEvent.KEYCODE_BUTTON_THUMBL: // L3
            case KeyEvent.KEYCODE_BUTTON_SELECT:
                return T_CROUCH;
            case KeyEvent.KEYCODE_BUTTON_START:
                return T_PAUSE;
            default:
                return -1;
        }
    }

    private static long lastL3 = 0L;
    private static long lastR3 = 0L;

    // ------------------------------------------------------------------
    // Entry points (called from injected activity overrides).
    // ------------------------------------------------------------------

    /**
     * @return true if the key event was consumed by the mapper.
     */
    public static boolean onKey(Activity a, KeyEvent ev) {
        if (a == null || ev == null) {
            return false;
        }
        int kc = ev.getKeyCode();
        int action = ev.getAction();
        int src = ev.getSource();

        boolean isPadButton = kc >= KeyEvent.KEYCODE_BUTTON_A
                && kc <= KeyEvent.KEYCODE_BUTTON_MODE; // 96..110
        boolean isDpad = kc >= KeyEvent.KEYCODE_DPAD_UP
                && kc <= KeyEvent.KEYCODE_DPAD_CENTER; // 19..23
        boolean gameSrc = (src & (InputDevice.SOURCE_GAMEPAD
                | InputDevice.SOURCE_JOYSTICK
                | InputDevice.SOURCE_DPAD)) != 0;

        if (!isPadButton && !(isDpad && gameSrc)) {
            return false; // not a controller key: let the system handle it
        }
        toastOnce(a);

        // L3 + R3 together toggles the whole mapping (works even when OFF).
        if (action == KeyEvent.ACTION_DOWN && ev.getRepeatCount() == 0
                && (kc == KeyEvent.KEYCODE_BUTTON_THUMBL
                || kc == KeyEvent.KEYCODE_BUTTON_THUMBR)) {
            long now = SystemClock.uptimeMillis();
            if (kc == KeyEvent.KEYCODE_BUTTON_THUMBL) {
                if (now - lastR3 < TOGGLE_WINDOW_MS) {
                    lastL3 = 0L;
                    lastR3 = 0L;
                    toggleEnabled(a);
                    return true;
                }
                lastL3 = now;
            } else {
                if (now - lastL3 < TOGGLE_WINDOW_MS) {
                    lastL3 = 0L;
                    lastR3 = 0L;
                    toggleEnabled(a);
                    return true;
                }
                lastR3 = now;
            }
        }

        if (!enabled) {
            return false;
        }

        if (isDpad && kc != KeyEvent.KEYCODE_DPAD_CENTER) {
            if (action == KeyEvent.ACTION_DOWN && ev.getRepeatCount() == 0) {
                setDpad(kc, true);
                updateMove(a);
            } else if (action == KeyEvent.ACTION_UP) {
                setDpad(kc, false);
                updateMove(a);
            }
            return true;
        }

        if (action == KeyEvent.ACTION_DOWN && ev.getRepeatCount() == 0) {
            int t = targetFor(kc);
            if (t >= 0) {
                tap(a, t);
            }
            return true;
        }
        // Swallow ups/repeats of mapped buttons so the game never sees doubles.
        return true;
    }

    private static void setDpad(int kc, boolean pressed) {
        switch (kc) {
            case KeyEvent.KEYCODE_DPAD_UP:
                dUp = pressed;
                break;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                dDown = pressed;
                break;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                dLeft = pressed;
                break;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                dRight = pressed;
                break;
            default:
                break;
        }
    }

    /**
     * @return true if the motion event was consumed by the mapper.
     */
    public static boolean onMotion(Activity a, MotionEvent ev) {
        if (a == null || ev == null) {
            return false;
        }
        int src = ev.getSource();
        boolean joystick = (src & InputDevice.SOURCE_JOYSTICK) != 0;
        boolean gamepad = (src & InputDevice.SOURCE_GAMEPAD) != 0;
        if (!joystick && !gamepad) {
            return false; // mouse hover etc.: not ours
        }
        if (ev.getAction() != MotionEvent.ACTION_MOVE) {
            return false;
        }
        toastOnce(a);
        if (!enabled) {
            return false;
        }
        int devId = ev.getDeviceId();

        // --- Left stick (+ hat) -> movement ---
        float lx = clamp1(ev.getAxisValue(MotionEvent.AXIS_X)
                + ev.getAxisValue(MotionEvent.AXIS_HAT_X));
        float ly = clamp1(ev.getAxisValue(MotionEvent.AXIS_Y)
                + ev.getAxisValue(MotionEvent.AXIS_HAT_Y));
        lastAx = applyDeadzone(lx, STICK_DEADZONE);
        lastAy = applyDeadzone(ly, STICK_DEADZONE);
        moveDevId = devId;
        updateMove(a);

        // --- Right stick -> look. DS3/PS3 normally reports Z/RZ;
        // some stacks/remappers use RX/RY instead: use the dominant pair. ---
        float z = ev.getAxisValue(MotionEvent.AXIS_Z);
        float rz = ev.getAxisValue(MotionEvent.AXIS_RZ);
        float rx = ev.getAxisValue(MotionEvent.AXIS_RX);
        float ry = ev.getAxisValue(MotionEvent.AXIS_RY);
        float sx;
        float sy;
        if (Math.abs(z) + Math.abs(rz) >= Math.abs(rx) + Math.abs(ry)) {
            sx = z;
            sy = rz;
        } else {
            sx = rx;
            sy = ry;
        }
        setLook(a, applyDeadzone(clamp1(sx), LOOK_DEADZONE),
                applyDeadzone(clamp1(sy), LOOK_DEADZONE), devId);
        return true;
    }
}
