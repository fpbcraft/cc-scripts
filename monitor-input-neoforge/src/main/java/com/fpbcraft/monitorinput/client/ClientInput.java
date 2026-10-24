package com.fpbcraft.monitorinput.client;

import com.fpbcraft.monitorinput.LeftClickPacket;
import com.fpbcraft.monitorinput.MonitorInputMod;
import net.minecraft.client.Minecraft;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.neoforge.event.entity.player.PlayerInteractEvent;
import net.neoforged.neoforge.network.PacketDistributor;

@EventBusSubscriber(modid=MonitorInputMod.MOD_ID,value=Dist.CLIENT)
public final class ClientInput {
    private ClientInput() {}
    @SubscribeEvent
    public static void onLeftClick(PlayerInteractEvent.LeftClickBlock event) {
        if (!event.getLevel().isClientSide()) return;
        // Sneak + attack intentionally preserves normal breaking/mining behavior.
        if (event.getEntity().isShiftKeyDown()) return;
        var name=BuiltInRegistries.BLOCK.getKey(event.getLevel().getBlockState(event.getPos()).getBlock());
        if (!name.getNamespace().equals("computercraft") || !name.getPath().equals("monitor_advanced"))return;
        // Only hijack the rendered face, not the sides/back (which players can still mine).
        if (!(Minecraft.getInstance().hitResult instanceof BlockHitResult hit)
                || hit.getType()!= HitResult.Type.BLOCK
                || !hit.getBlockPos().equals(event.getPos())
                || hit.getDirection()!=event.getFace())return;
        // For wall monitors the front is FACING; for floor/table and ceiling
        // monitors the front is ORIENTATION (UP / DOWN). Both must work.
        var state=event.getLevel().getBlockState(event.getPos());
        String facing="north", orientation="north";
        for (var property : state.getProperties()) {
            if (property.getName().equals("facing")) facing=state.getValue(property).toString();
            if (property.getName().equals("orientation")) orientation=state.getValue(property).toString();
        }
        String front=orientation.equals("north") ? facing : orientation;
        if (!front.equalsIgnoreCase(hit.getDirection().getName())) return;
        event.setCanceled(true); // Prevent breaking the advanced monitor.
        if (event.getAction()!=PlayerInteractEvent.LeftClickBlock.Action.START) return;
        var point=hit.getLocation();var pos=hit.getBlockPos();
        PacketDistributor.sendToServer(new LeftClickPacket(pos,hit.getDirection(),
                (float)(point.x-pos.getX()),(float)(point.y-pos.getY()),(float)(point.z-pos.getZ())));
    }
}