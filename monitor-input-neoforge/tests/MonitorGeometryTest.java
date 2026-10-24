import com.fpbcraft.monitorinput.MonitorGeometry;

public class MonitorGeometryTest {
    static void close(double a,double b) { if (Math.abs(a-b)>.01) throw new AssertionError(a+" vs "+b); }
    static void check(boolean b){if(!b)throw new AssertionError();}
    public static void main(String[] args){
        for(String facing:new String[]{"north","south","east","west"}) {
            var point=MonitorGeometry.normalized(.5f,.5f,.5f,facing,"north",0,0,1,1);
            check(point!=null);close(point.x(),.5);close(point.y(),.5);
            var point3=MonitorGeometry.normalized(.5f,.5f,.5f,facing,"north",2,0,5,5);
            check(point3!=null);close(point3.x(),.5);check(point3.y()>.85);
            check(MonitorGeometry.normalized(.5f,.5f,.5f,facing,"north",-1,0,5,5)==null);
        }
        for(String o:new String[]{"up","down"})for(String f:new String[]{"north","south","east","west"}){
            var point=MonitorGeometry.normalized(.5f,.5f,.5f,f,o,0,0,1,1);
            check(point!=null);close(point.x(),.5);close(point.y(),.5);
        }
        check(MonitorGeometry.normalized(.5f,.5f,.5f,"north","north",0,0,0,1)==null);
        System.out.println("MonitorGeometry tests passed");
    }
}