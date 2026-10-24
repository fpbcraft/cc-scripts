package com.fpbcraft.monitorinput.mixin;

import com.fpbcraft.monitorinput.MonitorGeometry;
import com.fpbcraft.monitorinput.MonitorInputAccess;
import dan200.computercraft.api.peripheral.IComputerAccess;
import net.minecraft.core.Direction;
import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import java.util.function.Consumer;

/** Keep CC's existing monitor_touch route unchanged; inject a separate left-click event. */
@Mixin(targets = "dan200.computercraft.shared.peripheral.monitor.MonitorBlockEntity", remap = false)
public abstract class MonitorBlockEntityMixin implements MonitorInputAccess {
    @Shadow @Final private boolean advanced;
    @Shadow private int xIndex;
    @Shadow private int yIndex;
    @Shadow private int width;
    @Shadow private int height;
    @Shadow public abstract Direction getDirection();
    @Shadow public abstract Direction getOrientation();
    @Shadow public abstract Direction getFront();
    @Shadow private void eachComputer(Consumer<IComputerAccess> visitor) { throw new AssertionError(); }

    @Override
    public Direction fpb$front() { return getFront(); }

    @Override
    public boolean fpb$handleClick(float x, float y, float z) {
        if (!advanced) return false;
        var p = MonitorGeometry.normalized(x,y,z,getDirection().getName(),getOrientation().getName(),
                                           xIndex,yIndex,width,height);
        if (p == null) return false;
        eachComputer(computer -> computer.queueEvent("monitor_left_click",computer.getAttachmentName(),p.x(),p.y()));
        return true;
    }
}