package com.fpbcraft.monitorinput;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.RegistryFriendlyByteBuf;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;
import net.minecraft.resources.ResourceLocation;

public record LeftClickPacket(BlockPos block, Direction face, float x, float y, float z) implements CustomPacketPayload {
    public static final Type<LeftClickPacket> TYPE = new Type<>(
        ResourceLocation.fromNamespaceAndPath(MonitorInputMod.MOD_ID,"left_click"));
    public static final StreamCodec<RegistryFriendlyByteBuf,LeftClickPacket> CODEC = StreamCodec.of(
        (buf,p) -> { buf.writeBlockPos(p.block);buf.writeByte(p.face.get3DDataValue());buf.writeFloat(p.x);buf.writeFloat(p.y);buf.writeFloat(p.z); },
        buf -> new LeftClickPacket(buf.readBlockPos(),Direction.from3DDataValue(buf.readUnsignedByte()),buf.readFloat(),buf.readFloat(),buf.readFloat())
    );
    @Override public Type<? extends CustomPacketPayload> type() {return TYPE;}
}