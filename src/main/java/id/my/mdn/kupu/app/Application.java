package id.my.mdn.kupu.app;

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
    
    public String getModuleIcon(String moduleName) {
        try {
            jakarta.faces.context.FacesContext ctx = jakarta.faces.context.FacesContext.getCurrentInstance();
            java.net.URL resource = ctx.getExternalContext().getResource("/WEB-INF/resources/images/" + moduleName + ".svg");
            return resource != null ? moduleName + ".svg" : "nothumb.svg";
        } catch (java.net.MalformedURLException ex) {
            return "nothumb.svg";
        }
    }
    
}
