//
// This file was generated by the JavaTM Architecture for XML Binding(JAXB) Reference Implementation, vJAXB 2.1.10 in JDK 6 
// See <a href="http://java.sun.com/xml/jaxb">http://java.sun.com/xml/jaxb</a> 
// Any modifications to this file will be lost upon recompilation of the source schema. 
// Generated on: 2011.06.02 at 10:58:15 AM CEST 
//


package simplenlg.xmlrealiser.wrapper;

import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlAttribute;
import javax.xml.bind.annotation.XmlElement;
import javax.xml.bind.annotation.XmlType;


/**
 * <p>Java class for DocumentRealisation complex type.
 * 
 * <p>The following schema fragment specifies the expected content contained within this class.
 * 
 * <pre>
 * &lt;complexType name="DocumentRealisation">
 *   &lt;complexContent>
 *     &lt;restriction base="{http://www.w3.org/2001/XMLSchema}anyType">
 *       &lt;sequence>
 *         &lt;element name="Document" type="{http://code.google.com/p/simplenlg/schemas/version1}DocumentElement"/>
 *         &lt;element name="Realisation" type="{http://www.w3.org/2001/XMLSchema}string" minOccurs="0"/>
 *       &lt;/sequence>
 *       &lt;attribute name="name" type="{http://www.w3.org/2001/XMLSchema}string" />
 *     &lt;/restriction>
 *   &lt;/complexContent>
 * &lt;/complexType>
 * </pre>
 * 
 * 
 */
@XmlAccessorType(XmlAccessType.FIELD)
@XmlType(name = "DocumentRealisation", propOrder = {
    "document",
    "realisation"
})
public class DocumentRealisation {

    @XmlElement(name = "Document", required = true)
    protected XmlDocumentElement document;
    @XmlElement(name = "Realisation")
    protected String realisation;
    @XmlAttribute
    protected String name;

    /**
     * Gets the value of the document property.
     * 
     * @return
     *     possible object is
     *     {@link XmlDocumentElement }
     *     
     */
    public XmlDocumentElement getDocument() {
        return document;
    }

    /**
     * Sets the value of the document property.
     * 
     * @param value
     *     allowed object is
     *     {@link XmlDocumentElement }
     *     
     */
    public void setDocument(XmlDocumentElement value) {
        this.document = value;
    }

    /**
     * Gets the value of the realisation property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getRealisation() {
        return realisation;
    }

    /**
     * Sets the value of the realisation property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setRealisation(String value) {
        this.realisation = value;
    }

    /**
     * Gets the value of the name property.
     * 
     * @return
     *     possible object is
     *     {@link String }
     *     
     */
    public String getName() {
        return name;
    }

    /**
     * Sets the value of the name property.
     * 
     * @param value
     *     allowed object is
     *     {@link String }
     *     
     */
    public void setName(String value) {
        this.name = value;
    }

}
