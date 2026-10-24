package com.fpbcraft.monitorinput;

/**
 * Maps a click on a single monitor block to zero-to-one coordinates of the
 * combined monitor display. Does not depend on CC: Graphics text/pixel scaling.
 */
public final class MonitorGeometry {
    private static final double BORDER = 2.0 / 16.0;
    private static final double MARGIN = 0.5 / 16.0;
    private MonitorGeometry() {}

    public record Point(double x, double y) {}

    public static Point normalized(float xx, float yy, float zz, String facing, String orientation,
                                   int column, int rowFromBottom, int width, int height) {
        if (width <= 0 || height <= 0 || column < 0 || column >= width || rowFromBottom < 0 || rowFromBottom >= height)
            return null;
        double x, y;
        switch (orientation) {
            case "north" -> {
                switch (facing) {
                    case "north" -> { x = 1 - xx; y = 1 - yy; }
                    case "south" -> { x = xx; y = 1 - yy; }
                    case "west" -> { x = zz; y = 1 - yy; }
                    case "east" -> { x = 1 - zz; y = 1 - yy; }
                    default -> { return null; }
                }
            }
            case "down" -> {
                switch (facing) {
                    case "north" -> { x = 1 - xx; y = zz; }
                    case "south" -> { x = xx; y = 1 - zz; }
                    case "west" -> { x = zz; y = xx; }
                    case "east" -> { x = 1 - zz; y = 1 - xx; }
                    default -> { return null; }
                }
            }
            case "up" -> {
                switch (facing) {
                    case "north" -> { x = 1 - xx; y = 1 - zz; }
                    case "south" -> { x = xx; y = zz; }
                    case "west" -> { x = zz; y = 1 - xx; }
                    case "east" -> { x = 1 - zz; y = xx; }
                    default -> { return null; }
                }
            }
            default -> { return null; }
        }
        // xIndex counts monitor columns from left. yIndex counts from bottom.
        x += column;
        y += height - rowFromBottom - 1;
        if (x < BORDER || x > width-BORDER || y < BORDER || y > height-BORDER) return null;
        double aw = width - 2*(BORDER + MARGIN);
        double ah = height - 2*(BORDER + MARGIN);
        double u = (x-BORDER-MARGIN)/aw;
        double v = (y-BORDER-MARGIN)/ah;
        // Normalize into [0, 1), deliberately avoiding a nonexistent last cell.
        return new Point(Math.min(Math.nextDown(1.0), Math.max(0.0, u)),
                         Math.min(Math.nextDown(1.0), Math.max(0.0, v)));
    }
}