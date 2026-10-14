import java.nio.file.*;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

/** Uses the Android application's exact POI engine, without Android SDK dependencies. */
public class POIInterop {
    public static void main(String[] args) throws Exception {
        Path root=Paths.get(args[0]);
        try (Workbook book=new XSSFWorkbook()) {
            Sheet sheet=book.createSheet("Grades");
            String[] headers={"学期","科目","考试名称","时间","分数","满分","分类","班排","年排","区排","反思"};
            Row head=sheet.createRow(0); for(int i=0;i<headers.length;i++) head.createCell(i).setCellValue(headers[i]);
            Row row=sheet.createRow(1);
            row.createCell(0).setCellValue("秋季"); row.createCell(1).setCellValue("数学"); row.createCell(2).setCellValue("=文字");
            row.createCell(3).setCellValue("2026-10-12"); row.createCell(4).setCellValue(89.5); row.createCell(5).setCellValue(100);
            row.createCell(6).setCellValue("月考"); row.createCell(8).setCellValue(1); row.createCell(10).setCellValue("中文\n第二行");
            try(var out=Files.newOutputStream(root.resolve("ios/StudyTrackTests/Fixtures/android-poi.xlsx"))) { book.write(out); }
        }
        try (Workbook book=WorkbookFactory.create(root.resolve("artifacts/ios-export.xlsx").toFile(),null,true)) {
            Sheet sheet=book.getSheetAt(0); Row row=sheet.getRow(1);
            if (!sheet.getSheetName().equals("Grades") || !row.getCell(2).getStringCellValue().equals("=文字") || row.getCell(4).getNumericCellValue()!=89.5 || row.getCell(8).getNumericCellValue()!=1 || row.getCell(7)!=null) {
                for (int i=0;i<11;i++) System.out.println("Column "+i+": "+row.getCell(i));
                throw new AssertionError("iOS -> Android POI mismatch");
            }
        }
        System.out.println("PASS: iOS XLSX read by Android's Apache POI 5.2.3; POI fixture generated");
    }
}
