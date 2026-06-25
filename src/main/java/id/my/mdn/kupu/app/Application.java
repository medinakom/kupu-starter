package id.my.mdn.kupu.app;

import id.my.mdn.kupu.core.base.AbstractApplication;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Default;
import jakarta.faces.annotation.FacesConfig;
import jakarta.inject.Named;

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
    
}
