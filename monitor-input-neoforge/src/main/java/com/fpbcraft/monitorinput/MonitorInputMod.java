package com.fpbcraft.monitorinput;

import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.network.event.RegisterPayloadHandlersEvent;

@Mod(MonitorInputMod.MOD_ID)
public final class MonitorInputMod {
    public static final String MOD_ID="fpbmonitorinput";
    public MonitorInputMod(IEventBus modBus) { modBus.addListener(MonitorInputMod::registerPayloads); }

    private static void registerPayloads(RegisterPayloadHandlersEvent event) {
        event.registrar("1").playToServer(LeftClickPacket.TYPE, LeftClickPacket.CODEC,
            (packet,context) -> context.enqueueWork(() -> {
                if (context.player() instanceof ServerPlayer player) handle(player,packet);
            }));
    }

    private static void handle(ServerPlayer player, LeftClickPacket packet) {
        // Do not trust coordinates from a client packet: enforce reach and raycast.
        if (player.distanceToSqr(packet.block().getX()+0.5, packet.block().getY()+0.5,packet.block().getZ()+0.5)>64) return;
        if (!(player.pick(6.0,1.0f,false) instanceof BlockHitResult hit) || hit.getType()!=HitResult.Type.BLOCK) return;
        if (!hit.getBlockPos().equals(packet.block()) || hit.getDirection()!=packet.face()) return;
        if (!(player.level().getBlockEntity(packet.block()) instanceof MonitorInputAccess monitor)) return;
        if (monitor.fpb$front()!=packet.face()) return;
        if (!Float.isFinite(packet.x())||!Float.isFinite(packet.y())||!Float.isFinite(packet.z())) return;
        if (packet.x()<-0.001f||packet.x()>1.001f||packet.y()<-0.001f||packet.y()>1.001f||packet.z()<-0.001f||packet.z()>1.001f)return;
        monitor.fpb$handleClick(packet.x(),packet.y(),packet.z());
    }
}