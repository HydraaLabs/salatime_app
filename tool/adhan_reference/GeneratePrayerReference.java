import com.batoulapps.adhan2.CalculationMethod;
import com.batoulapps.adhan2.CalculationParameters;
import com.batoulapps.adhan2.Coordinates;
import com.batoulapps.adhan2.Madhab;
import com.batoulapps.adhan2.PrayerTimes;
import com.batoulapps.adhan2.data.DateComponents;
import java.time.LocalDate;

/** Independent fixtures from the public Adhan Kotlin JVM release, not SalaTime. */
public final class GeneratePrayerReference {
    public static void main(String[] args) {
        String[][] places = {
            {"Casablanca", "33.5731", "-7.5898", "Africa/Casablanca"},
            {"Paris", "48.8566", "2.3522", "Europe/Paris"},
            {"Dubai", "25.2048", "55.2708", "Asia/Dubai"},
            {"Singapore", "1.3521", "103.8198", "Asia/Singapore"},
            {"Oslo", "59.9139", "10.7522", "Europe/Oslo"},
            {"Sydney", "-33.8688", "151.2093", "Australia/Sydney"},
            {"New York", "40.7128", "-74.0060", "America/New_York"},
            {"Latitude boundary", "48.0", "2.0", "Europe/Paris"}
        };
        String[] dates = {"2026-02-20", "2026-03-08", "2026-03-29",
                "2026-06-21", "2026-09-16", "2026-10-25", "2026-12-21"};
        String[][] methods = {
            {"3", "MUSLIM_WORLD_LEAGUE"}, {"5", "EGYPTIAN"}, {"1", "KARACHI"},
            {"4", "UMM_AL_QURA"}, {"16", "DUBAI"}, {"15", "MOON_SIGHTING_COMMITTEE"},
            {"2", "NORTH_AMERICA"}, {"9", "KUWAIT"}, {"10", "QATAR"},
            {"11", "SINGAPORE"}, {"13", "TURKEY"}
        };
        System.out.println("city,lat,lng,timezone,date,method,school,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Isha");
        for (String[] place : places) for (String date : dates) for (String[] method : methods) {
            for (Madhab school : Madhab.values()) {
                CalculationParameters p = CalculationMethod.valueOf(method[1]).getParameters();
                p = p.copy(p.getFajrAngle(), p.getIshaAngle(), p.getIshaInterval(),
                        p.getMethod(), school, p.getHighLatitudeRule(), p.getPrayerAdjustments(),
                        p.getMethodAdjustments(), p.getRounding(), p.getShafaq());
                LocalDate d = LocalDate.parse(date);
                PrayerTimes times = new PrayerTimes(
                        new Coordinates(Double.parseDouble(place[1]), Double.parseDouble(place[2])),
                        new DateComponents(d.getYear(), d.getMonthValue(), d.getDayOfMonth()), p);
                System.out.println(String.join(",", place[0], place[1], place[2], place[3], date,
                        method[0], school == Madhab.HANAFI ? "HANAFI" : "STANDARD",
                        times.getFajr().toString(), times.getSunrise().toString(),
                        times.getDhuhr().toString(), times.getAsr().toString(),
                        times.getMaghrib().toString(), times.getIsha().toString()));
            }
        }
    }
}
