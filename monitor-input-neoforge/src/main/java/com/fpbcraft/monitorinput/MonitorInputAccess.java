package com.fpbcraft.monitorinput;

import net.minecraft.core.Direction;

/** Injected into CC:Tweaked's Advanced Monitor block entity. */
public interface MonitorInputAccess {
    boolean fpb$handleClick(float x, float y, float z);
    Direction fpb$front();
}