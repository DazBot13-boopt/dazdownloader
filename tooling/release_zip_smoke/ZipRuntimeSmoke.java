import org.apache.commons.compress.archivers.zip.ExtraFieldUtils;
import org.apache.commons.compress.archivers.zip.ZipExtraField;
import org.apache.commons.compress.archivers.zip.ZipShort;

/** Runs after R8, unlike the unminified JVM unit tests. */
public final class ZipRuntimeSmoke {
    public static void main(String[] args) throws Exception {
        int[] ids = {0x756e, 0x5455, 0x7875, 0xcafe, 0x7075, 0x6375, 0x0001, 0x000a};
        for (int id : ids) {
            ZipExtraField field = ExtraFieldUtils.createExtraField(new ZipShort(id));
            if (field.getHeaderId().getValue() != id
                    || field.getClass().getSimpleName().equals("UnrecognizedExtraField")) {
                throw new AssertionError("ZIP field was removed by R8: " + id);
            }
        }
        System.out.println("ZIP runtime initialization passed after R8.");
    }
}
