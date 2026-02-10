package id.my.mdn.kupu;

import id.my.mdn.kupu.core.base.AbstractApplication;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Default;
import jakarta.faces.annotation.FacesConfig;
import jakarta.inject.Named;
import java.util.Locale;

/**
 *
 * @author aphasan
 */
@Named("theApp")
@FacesConfig
@ApplicationScoped
@Default
public class Application extends AbstractApplication {

    @PostConstruct
    @Override
    protected void init() {
        super.init();
    }
    
    public Locale getLocale() {
        return new Locale("in_id");
    }
    
    public String getLocalization() {
        return getLocale().toString();
//                .replace("in_id", "in");
    }
    
}
